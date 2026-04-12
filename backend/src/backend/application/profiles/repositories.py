"""Profile repository port (Protocol interfaces for use cases)."""

import uuid
from typing import Protocol

from backend.domain.profiles.entities.profile import MeProfile, PublicUserProfile


class IProfileRepository(Protocol):
    async def get_public_by_id(self, user_id: uuid.UUID) -> PublicUserProfile | None: ...

    async def get_me_by_id(self, user_id: uuid.UUID) -> MeProfile | None: ...

    async def update_me(
        self,
        user_id: uuid.UUID,
        *,
        username: str | None = None,
        bio: str | None = None,
        preferred_genres: list[str] | None = None,
    ) -> MeProfile: ...
