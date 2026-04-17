import uuid
from datetime import datetime

import uuid6
from sqlalchemy import and_, delete, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.posts.repositories import IPostRepository
from backend.domain.posts.value_objects.post_cursor import PostCursor, encode_cursor
from backend.infrastructure.persistence.models.attachment import Attachment, AttachmentSpotifyLink, AttachmentText
from backend.infrastructure.persistence.models.post import Post, Privacy
from backend.infrastructure.persistence.models.post_interaction import (
    PostActivityNotification,
    PostActivityType,
    PostComment,
    PostLike,
)
from backend.infrastructure.persistence.models.user import User


class SqlAlchemyPostRepository(IPostRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(
        self,
        user_id: uuid.UUID,
        privacy: str,
        text: str | None = None,
        spotify_url: str | None = None,
    ) -> Post:
        model = Post(id=uuid6.uuid7(), user_id=user_id, privacy=Privacy(privacy))
        self._session.add(model)
        await self._session.flush()
        trimmed_text = text.strip() if text else None
        if trimmed_text:
            self._session.add(AttachmentText(id=uuid6.uuid7(), post_id=model.id, content=trimmed_text))
        trimmed_spotify_url = spotify_url.strip() if spotify_url else None
        if trimmed_spotify_url:
            self._session.add(AttachmentSpotifyLink(id=uuid6.uuid7(), post_id=model.id, url=trimmed_spotify_url))
        await self._session.flush()
        return model

    async def list_for_authors(
        self,
        author_ids: list[uuid.UUID],
        page_size: int,
        cursor_created_at: datetime | None,
        cursor_id: uuid.UUID | None,
    ) -> tuple[list[Post], dict[uuid.UUID, list[Attachment]], str | None]:
        if not author_ids:
            return [], {}, None

        stmt = select(Post).where(Post.user_id.in_(author_ids))
        if cursor_created_at is not None and cursor_id is not None:
            stmt = stmt.where(
                or_(
                    Post.created_at < cursor_created_at,
                    and_(Post.created_at == cursor_created_at, Post.id < cursor_id),
                )
            )

        stmt = stmt.order_by(Post.created_at.desc(), Post.id.desc()).limit(page_size)
        posts = (await self._session.execute(stmt)).scalars().all()
        if not posts:
            return [], {}, None

        post_ids = [post.id for post in posts]
        attachments_stmt = select(Attachment).where(Attachment.post_id.in_(post_ids)).order_by(Attachment.created_at.asc())
        attachments = (await self._session.execute(attachments_stmt)).scalars().all()
        attachment_map: dict[uuid.UUID, list[Attachment]] = {}
        for attachment in attachments:
            if attachment.post_id is None:
                continue
            attachment_map.setdefault(attachment.post_id, []).append(attachment)

        next_cursor: str | None = None
        if len(posts) == page_size:
            last = posts[-1]
            next_cursor = encode_cursor(PostCursor(created_at=last.created_at, id=last.id))

        return posts, attachment_map, next_cursor

    async def get_by_id(self, post_id: uuid.UUID) -> Post | None:
        return await self._session.get(Post, post_id)

    async def list_interaction_counts(
        self,
        post_ids: list[uuid.UUID],
    ) -> tuple[dict[uuid.UUID, int], dict[uuid.UUID, int]]:
        if not post_ids:
            return {}, {}

        likes_stmt = (
            select(PostLike.post_id, func.count(PostLike.id))
            .where(PostLike.post_id.in_(post_ids))
            .group_by(PostLike.post_id)
        )
        comments_stmt = (
            select(PostComment.post_id, func.count(PostComment.id))
            .where(PostComment.post_id.in_(post_ids))
            .group_by(PostComment.post_id)
        )
        likes_rows = (await self._session.execute(likes_stmt)).all()
        comments_rows = (await self._session.execute(comments_stmt)).all()

        like_counts = {post_id: int(count) for post_id, count in likes_rows}
        comment_counts = {post_id: int(count) for post_id, count in comments_rows}
        return like_counts, comment_counts

    async def list_liked_post_ids(
        self,
        user_id: uuid.UUID,
        post_ids: list[uuid.UUID],
    ) -> set[uuid.UUID]:
        if not post_ids:
            return set()
        stmt = select(PostLike.post_id).where(
            and_(PostLike.user_id == user_id, PostLike.post_id.in_(post_ids))
        )
        rows = (await self._session.execute(stmt)).scalars().all()
        return set(rows)

    async def has_like(self, post_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        stmt = select(PostLike.id).where(
            and_(PostLike.post_id == post_id, PostLike.user_id == user_id)
        )
        return (await self._session.execute(stmt)).scalar_one_or_none() is not None

    async def add_like(self, post_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        if await self.has_like(post_id=post_id, user_id=user_id):
            return False
        self._session.add(PostLike(id=uuid6.uuid7(), post_id=post_id, user_id=user_id))
        await self._session.flush()
        return True

    async def remove_like(self, post_id: uuid.UUID, user_id: uuid.UUID) -> bool:
        result = await self._session.execute(
            delete(PostLike).where(
                and_(PostLike.post_id == post_id, PostLike.user_id == user_id)
            )
        )
        await self._session.flush()
        return bool(result.rowcount)

    async def get_post_engagement(
        self,
        post_id: uuid.UUID,
        user_id: uuid.UUID,
    ) -> tuple[int, int, bool]:
        like_counts, comment_counts = await self.list_interaction_counts([post_id])
        liked = await self.has_like(post_id=post_id, user_id=user_id)
        return (
            like_counts.get(post_id, 0),
            comment_counts.get(post_id, 0),
            liked,
        )

    async def create_comment(
        self,
        post_id: uuid.UUID,
        user_id: uuid.UUID,
        content: str,
    ) -> PostComment:
        trimmed = content.strip()
        comment = PostComment(
            id=uuid6.uuid7(),
            post_id=post_id,
            user_id=user_id,
            content=trimmed,
        )
        self._session.add(comment)
        await self._session.flush()
        return comment

    async def list_comments_with_authors(
        self,
        post_id: uuid.UUID,
        limit: int = 100,
    ) -> list[tuple[PostComment, str]]:
        stmt = (
            select(PostComment, User.username)
            .join(User, User.id == PostComment.user_id)
            .where(PostComment.post_id == post_id)
            .order_by(PostComment.created_at.asc())
            .limit(limit)
        )
        rows = (await self._session.execute(stmt)).all()
        return [(row[0], row[1]) for row in rows]

    async def create_activity_notification(
        self,
        *,
        recipient_user_id: uuid.UUID,
        actor_user_id: uuid.UUID,
        post_id: uuid.UUID,
        activity_type: PostActivityType,
        comment_preview: str | None = None,
    ) -> PostActivityNotification:
        notification = PostActivityNotification(
            id=uuid6.uuid7(),
            recipient_user_id=recipient_user_id,
            actor_user_id=actor_user_id,
            post_id=post_id,
            activity_type=activity_type,
            comment_preview=comment_preview,
        )
        self._session.add(notification)
        await self._session.flush()
        return notification

    async def list_activity_notifications(
        self,
        recipient_user_id: uuid.UUID,
        limit: int = 100,
    ) -> list[tuple[PostActivityNotification, str]]:
        stmt = (
            select(PostActivityNotification, User.username)
            .join(User, User.id == PostActivityNotification.actor_user_id)
            .where(PostActivityNotification.recipient_user_id == recipient_user_id)
            .order_by(PostActivityNotification.created_at.desc())
            .limit(limit)
        )
        rows = (await self._session.execute(stmt)).all()
        return [(row[0], row[1]) for row in rows]
