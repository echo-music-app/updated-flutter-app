"""Admin access token persistence repository."""

import uuid
from datetime import UTC, datetime

from sqlalchemy import update
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.admin_auth import AdminAccessToken


class AdminAuthTokenRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def create(
        self,
        *,
        admin_id: uuid.UUID,
        token_hash: bytes,
        expires_at: datetime,
        created_at: datetime,
    ) -> AdminAccessToken:
        token = AdminAccessToken(
            admin_id=admin_id,
            token_hash=token_hash,
            expires_at=expires_at,
            revoked_at=None,
            created_at=created_at,
        )
        self._db.add(token)
        await self._db.flush()
        await self._db.refresh(token)
        return token

    async def revoke(self, *, token_hash: bytes) -> None:
        await self._db.execute(
            update(AdminAccessToken).where(AdminAccessToken.token_hash == token_hash).values(revoked_at=datetime.now(UTC))
        )
