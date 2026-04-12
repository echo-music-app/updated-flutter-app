import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from backend.application.ports.attachment_url_signer import AttachmentUrlSigner
from backend.core.config import Settings
from backend.domain.posts.repositories import IFriendRepository, IPostRepository
from backend.domain.posts.value_objects.post_cursor import PostCursor, decode_cursor, encode_cursor
from backend.infrastructure.persistence.models.post import Privacy


@dataclass(slots=True)
class AttachmentDTO:
    id: uuid.UUID
    type: str
    created_at: datetime
    content: str | None = None
    url: str | None = None
    url_provider: str | None = None
    expires_at: datetime | None = None
    track_id: str | None = None
    storage_key: str | None = None
    mime_type: str | None = None
    size_bytes: int | None = None


@dataclass(slots=True)
class PostDTO:
    id: uuid.UUID
    user_id: uuid.UUID
    privacy: str
    attachments: list[AttachmentDTO]
    created_at: datetime
    updated_at: datetime


@dataclass(slots=True)
class PostListDTO:
    items: list[PostDTO]
    count: int
    page_size: int
    next_cursor: str | None


class CreatePostUseCase:
    def __init__(self, post_repo: IPostRepository) -> None:
        self._post_repo = post_repo

    async def execute(self, *, user_id: uuid.UUID, privacy: str) -> PostDTO:
        valid = {item.value for item in Privacy}
        if privacy not in valid:
            raise ValueError("Invalid privacy value")

        created = await self._post_repo.create(user_id=user_id, privacy=privacy)
        return PostDTO(
            id=created.id,
            user_id=created.user_id,
            privacy=str(created.privacy.value if hasattr(created.privacy, "value") else created.privacy),
            attachments=[],
            created_at=created.created_at,
            updated_at=created.updated_at,
        )


class ListPostsUseCase:
    def __init__(
        self,
        post_repo: IPostRepository,
        friend_repo: IFriendRepository,
        signers: dict[str, AttachmentUrlSigner],
        settings: Settings,
    ) -> None:
        self._post_repo = post_repo
        self._friend_repo = friend_repo
        self._signers = signers
        self._settings = settings

    async def list_my_posts(self, *, user_id: uuid.UUID, page_size: int, cursor: str | None) -> PostListDTO:
        return await self._list_for_authors(author_ids=[user_id], page_size=page_size, cursor=cursor)

    async def list_user_posts(self, *, target_user_id: uuid.UUID, page_size: int, cursor: str | None) -> PostListDTO:
        return await self._list_for_authors(author_ids=[target_user_id], page_size=page_size, cursor=cursor)

    async def list_following_feed(self, *, user_id: uuid.UUID, page_size: int, cursor: str | None) -> PostListDTO:
        following = await self._friend_repo.get_following_user_ids(user_id)
        if not following:
            return PostListDTO(items=[], count=0, page_size=page_size, next_cursor=None)
        return await self._list_for_authors(author_ids=following, page_size=page_size, cursor=cursor)

    async def _list_for_authors(self, *, author_ids: list[uuid.UUID], page_size: int, cursor: str | None) -> PostListDTO:
        cursor_created_at: datetime | None = None
        cursor_id: uuid.UUID | None = None
        if cursor:
            parsed = decode_cursor(cursor)
            cursor_created_at = parsed.created_at
            cursor_id = parsed.id

        posts, attachments_map, next_cursor = await self._post_repo.list_for_authors(
            author_ids=author_ids,
            page_size=page_size,
            cursor_created_at=cursor_created_at,
            cursor_id=cursor_id,
        )

        items: list[PostDTO] = []
        for post in posts:
            attachment_dtos: list[AttachmentDTO] = []
            for attachment in attachments_map.get(post.id, []):
                provider = attachment.url_provider_override or self._settings.attachment_url_provider_default
                signer = self._signers.get(provider)
                signed_url: str | None = None
                expires_at: datetime | None = None
                if signer and attachment.storage_key:
                    try:
                        signed_url = await signer.sign(
                            storage_key=attachment.storage_key,
                            ttl_seconds=self._settings.attachment_url_ttl_seconds,
                        )
                        expires_at = datetime.now(UTC)
                    except Exception:
                        signed_url = None
                        expires_at = None

                attachment_dtos.append(
                    AttachmentDTO(
                        id=attachment.id,
                        type=str(
                            attachment.attachment_type.value if hasattr(attachment.attachment_type, "value") else attachment.attachment_type
                        ),
                        created_at=attachment.created_at,
                        content=attachment.content,
                        url=signed_url if signed_url else attachment.url,
                        url_provider=provider if signed_url else None,
                        expires_at=expires_at,
                        track_id=attachment.track_id,
                        storage_key=attachment.storage_key,
                        mime_type=attachment.mime_type,
                        size_bytes=attachment.size_bytes,
                    )
                )

            items.append(
                PostDTO(
                    id=post.id,
                    user_id=post.user_id,
                    privacy=str(post.privacy.value if hasattr(post.privacy, "value") else post.privacy),
                    attachments=attachment_dtos,
                    created_at=post.created_at,
                    updated_at=post.updated_at,
                )
            )

        return PostListDTO(items=items, count=len(items), page_size=page_size, next_cursor=next_cursor)


def compute_next_cursor(posts: list[PostDTO], page_size: int) -> str | None:
    if len(posts) < page_size:
        return None
    last = posts[-1]
    return encode_cursor(PostCursor(created_at=last.created_at, id=last.id))
