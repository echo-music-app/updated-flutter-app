import uuid
from datetime import datetime

import uuid6
from sqlalchemy import and_, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.posts.repositories import IPostRepository
from backend.domain.posts.value_objects.post_cursor import PostCursor, encode_cursor
from backend.infrastructure.persistence.models.attachment import Attachment
from backend.infrastructure.persistence.models.post import Post, Privacy


class SqlAlchemyPostRepository(IPostRepository):
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create(self, user_id: uuid.UUID, privacy: str) -> Post:
        model = Post(id=uuid6.uuid7(), user_id=user_id, privacy=Privacy(privacy))
        self._session.add(model)
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
