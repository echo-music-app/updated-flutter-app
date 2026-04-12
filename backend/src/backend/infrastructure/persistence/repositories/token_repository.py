import uuid
from datetime import datetime

import uuid6
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.auth import AccessToken, RefreshToken


class SqlAlchemyTokenRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def create_access_token(self, user_id: uuid.UUID, token_hash: bytes, expires_at: datetime) -> AccessToken:
        access_token = AccessToken(
            id=uuid6.uuid7(),
            token_hash=token_hash,
            user_id=user_id,
            expires_at=expires_at,
        )
        self._session.add(access_token)
        await self._session.flush()
        return access_token

    async def create_refresh_token(
        self,
        user_id: uuid.UUID,
        token_hash: bytes,
        access_token_id: uuid.UUID,
        expires_at: datetime,
    ) -> RefreshToken:
        refresh_token = RefreshToken(
            id=uuid6.uuid7(),
            token_hash=token_hash,
            user_id=user_id,
            access_token_id=access_token_id,
            expires_at=expires_at,
        )
        self._session.add(refresh_token)
        await self._session.flush()
        return refresh_token

    async def get_refresh_by_hash(self, token_hash: bytes) -> RefreshToken | None:
        result = await self._session.execute(select(RefreshToken).where(RefreshToken.token_hash == token_hash))
        return result.scalar_one_or_none()

    async def get_access_by_id(self, access_token_id: uuid.UUID) -> AccessToken | None:
        result = await self._session.execute(select(AccessToken).where(AccessToken.id == access_token_id))
        return result.scalar_one_or_none()

    async def revoke_access(self, access_token_id: uuid.UUID, revoked_at: datetime) -> None:
        access_token = await self.get_access_by_id(access_token_id)
        if access_token:
            access_token.revoked_at = revoked_at

    async def revoke_refresh(self, refresh_token_id: uuid.UUID, revoked_at: datetime) -> None:
        result = await self._session.execute(select(RefreshToken).where(RefreshToken.id == refresh_token_id))
        refresh_token = result.scalar_one_or_none()
        if refresh_token:
            refresh_token.revoked_at = revoked_at

    async def rotate_refresh(self, refresh_token_id: uuid.UUID, rotated_at: datetime) -> None:
        result = await self._session.execute(select(RefreshToken).where(RefreshToken.id == refresh_token_id))
        refresh_token = result.scalar_one_or_none()
        if refresh_token:
            refresh_token.rotated_at = rotated_at

    async def revoke_refresh_tokens_for_access(self, user_id: uuid.UUID, access_token_id: uuid.UUID, revoked_at: datetime) -> None:
        result = await self._session.execute(
            select(RefreshToken).where(
                RefreshToken.user_id == user_id,
                RefreshToken.access_token_id == access_token_id,
                RefreshToken.revoked_at.is_(None),
            )
        )
        for refresh_token in result.scalars():
            refresh_token.revoked_at = revoked_at
