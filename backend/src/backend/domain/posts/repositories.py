import uuid
from datetime import datetime
from typing import Protocol


class IPost(Protocol):
    id: uuid.UUID
    user_id: uuid.UUID
    privacy: object
    created_at: datetime
    updated_at: datetime


class IAttachment(Protocol):
    id: uuid.UUID
    attachment_type: str
    post_id: uuid.UUID | None
    content: str | None
    url: str | None
    track_id: str | None
    storage_key: str | None
    mime_type: str | None
    size_bytes: int | None
    url_provider_override: str | None
    created_at: datetime


class IPostRepository(Protocol):
    async def create(self, user_id: uuid.UUID, privacy: str) -> IPost: ...

    async def list_for_authors(
        self,
        author_ids: list[uuid.UUID],
        page_size: int,
        cursor_created_at: datetime | None,
        cursor_id: uuid.UUID | None,
    ) -> tuple[list[IPost], dict[uuid.UUID, list[IAttachment]], str | None]: ...


class IFriendRepository(Protocol):
    async def get_following_user_ids(self, user_id: uuid.UUID) -> list[uuid.UUID]: ...
