import uuid
from datetime import UTC, datetime

import uuid6
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials


class SqlAlchemySpotifyCredentialsRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_user_id(self, user_id: uuid.UUID) -> SpotifyCredentials | None:
        result = await self._session.execute(select(SpotifyCredentials).where(SpotifyCredentials.user_id == user_id))
        return result.scalar_one_or_none()

    async def get_by_spotify_user_id(self, spotify_user_id: str) -> SpotifyCredentials | None:
        result = await self._session.execute(select(SpotifyCredentials).where(SpotifyCredentials.spotify_user_id == spotify_user_id))
        return result.scalar_one_or_none()

    async def upsert(
        self,
        spotify_user_id: str,
        user_id: uuid.UUID,
        access_token: bytes,
        refresh_token: bytes,
        token_expiry: datetime,
        scope: str,
    ) -> SpotifyCredentials:
        existing = await self.get_by_spotify_user_id(spotify_user_id)
        if existing:
            existing.access_token = access_token
            existing.refresh_token = refresh_token
            existing.token_expiry = token_expiry
            existing.scope = scope
            existing.updated_at = datetime.now(UTC)
            existing.user_id = user_id
            await self._session.flush()
            return existing

        cred = SpotifyCredentials(
            id=uuid6.uuid7(),
            user_id=user_id,
            spotify_user_id=spotify_user_id,
            access_token=access_token,
            refresh_token=refresh_token,
            token_expiry=token_expiry,
            scope=scope,
        )
        self._session.add(cred)
        await self._session.flush()
        return cred

    async def update_tokens(
        self,
        cred_id: uuid.UUID,
        access_token: bytes,
        refresh_token: bytes | None,
        token_expiry: datetime,
    ) -> None:
        result = await self._session.execute(select(SpotifyCredentials).where(SpotifyCredentials.id == cred_id))
        cred = result.scalar_one_or_none()
        if cred:
            cred.access_token = access_token
            if refresh_token is not None:
                cred.refresh_token = refresh_token
            cred.token_expiry = token_expiry
            cred.updated_at = datetime.now(UTC)

    async def delete(self, cred_id: uuid.UUID) -> None:
        result = await self._session.execute(select(SpotifyCredentials).where(SpotifyCredentials.id == cred_id))
        cred = result.scalar_one_or_none()
        if cred:
            await self._session.delete(cred)
            await self._session.flush()
