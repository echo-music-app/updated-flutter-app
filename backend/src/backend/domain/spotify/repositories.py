import uuid
from datetime import datetime
from typing import Protocol


class ISpotifyCredentials(Protocol):
    id: uuid.UUID
    user_id: uuid.UUID
    spotify_user_id: str
    access_token: bytes
    refresh_token: bytes
    token_expiry: datetime
    scope: str


class ISpotifyCredentialsRepository(Protocol):
    async def get_by_user_id(self, user_id: uuid.UUID) -> ISpotifyCredentials | None: ...

    async def get_by_spotify_user_id(self, spotify_user_id: str) -> ISpotifyCredentials | None: ...

    async def upsert(
        self,
        spotify_user_id: str,
        user_id: uuid.UUID,
        access_token: bytes,
        refresh_token: bytes,
        token_expiry: datetime,
        scope: str,
    ) -> ISpotifyCredentials: ...

    async def update_tokens(
        self,
        cred_id: uuid.UUID,
        access_token: bytes,
        refresh_token: bytes | None,
        token_expiry: datetime,
    ) -> None: ...

    async def delete(self, cred_id: uuid.UUID) -> None: ...
