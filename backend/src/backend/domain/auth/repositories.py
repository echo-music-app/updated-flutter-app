import uuid
from datetime import datetime
from typing import Protocol


class IUser(Protocol):
    id: uuid.UUID
    email: str
    username: str
    password_hash: str
    google_subject: str | None
    status: object
    email_verified_at: datetime | None
    email_verification_code_hash: bytes | None
    email_verification_expires_at: datetime | None
    email_verification_sent_at: datetime | None


class IAccessToken(Protocol):
    id: uuid.UUID
    token_hash: bytes
    user_id: uuid.UUID
    expires_at: datetime
    revoked_at: datetime | None


class IRefreshToken(Protocol):
    id: uuid.UUID
    token_hash: bytes
    user_id: uuid.UUID
    access_token_id: uuid.UUID | None
    expires_at: datetime
    rotated_at: datetime | None
    revoked_at: datetime | None


class IUserRepository(Protocol):
    async def get_by_google_subject(self, google_subject: str) -> IUser | None: ...

    async def get_by_email(self, email: str) -> IUser | None: ...

    async def get_by_username(self, username: str) -> IUser | None: ...

    async def get_by_id(self, user_id: uuid.UUID) -> IUser | None: ...

    async def create(self, email: str, username: str, password_hash: str) -> IUser: ...

    async def set_email_verification(
        self,
        user_id: uuid.UUID,
        *,
        code_hash: bytes,
        expires_at: datetime,
        sent_at: datetime,
    ) -> IUser | None: ...

    async def mark_email_verified(self, user_id: uuid.UUID, *, verified_at: datetime) -> IUser | None: ...

    async def link_google_account(
        self,
        user_id: uuid.UUID,
        *,
        google_subject: str,
        verified_at: datetime,
    ) -> IUser | None: ...


class ITokenRepository(Protocol):
    async def create_access_token(self, user_id: uuid.UUID, token_hash: bytes, expires_at: datetime) -> IAccessToken: ...

    async def create_refresh_token(
        self,
        user_id: uuid.UUID,
        token_hash: bytes,
        access_token_id: uuid.UUID,
        expires_at: datetime,
    ) -> IRefreshToken: ...

    async def get_refresh_by_hash(self, token_hash: bytes) -> IRefreshToken | None: ...

    async def get_access_by_id(self, access_token_id: uuid.UUID) -> IAccessToken | None: ...

    async def revoke_access(self, access_token_id: uuid.UUID, revoked_at: datetime) -> None: ...

    async def revoke_refresh(self, refresh_token_id: uuid.UUID, revoked_at: datetime) -> None: ...

    async def rotate_refresh(self, refresh_token_id: uuid.UUID, rotated_at: datetime) -> None: ...

    async def revoke_refresh_tokens_for_access(self, user_id: uuid.UUID, access_token_id: uuid.UUID, revoked_at: datetime) -> None: ...
