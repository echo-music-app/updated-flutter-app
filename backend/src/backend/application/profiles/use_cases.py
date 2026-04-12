"""Profile use cases."""

import re
import uuid

from backend.application.profiles.repositories import IProfileRepository
from backend.domain.profiles.entities.profile import MeProfile, MeProfilePatch, PublicUserProfile
from backend.domain.profiles.exceptions import InvalidProfilePatchError, ProfileNotFoundError

_USERNAME_RE = re.compile(r"^[a-zA-Z0-9_.\-]+$")
_NON_MUTABLE_FIELDS = {"email", "status", "password_hash", "is_artist"}


def _validate_patch(patch: MeProfilePatch) -> None:
    """Validate and normalize a MeProfilePatch; raises InvalidProfilePatchError on failures."""
    if patch.username is None and patch.bio is None and patch.preferred_genres is None:
        raise InvalidProfilePatchError("At least one mutable field must be provided")

    if patch.username is not None:
        if not (3 <= len(patch.username) <= 50):
            raise InvalidProfilePatchError("username must be between 3 and 50 characters")
        if not _USERNAME_RE.match(patch.username):
            raise InvalidProfilePatchError("username contains invalid characters")

    if patch.bio is not None and len(patch.bio) > 200:
        raise InvalidProfilePatchError("bio must be at most 200 characters")

    if patch.preferred_genres is not None:
        for genre in patch.preferred_genres:
            if not genre or not genre.strip():
                raise InvalidProfilePatchError("preferred_genres must contain non-empty strings")


def _normalize_patch(patch: MeProfilePatch) -> MeProfilePatch:
    """Normalize patch values (deduplicate preferred_genres, etc.)."""
    genres = patch.preferred_genres
    if genres is not None:
        seen: set[str] = set()
        deduped: list[str] = []
        for g in genres:
            if g not in seen:
                seen.add(g)
                deduped.append(g)
        genres = deduped
    return MeProfilePatch(username=patch.username, bio=patch.bio, preferred_genres=genres)


class ProfileUseCases:
    def __init__(self, profile_repo: IProfileRepository) -> None:
        self._profile_repo = profile_repo

    async def get_user_profile(self, user_id: uuid.UUID) -> PublicUserProfile:
        profile = await self._profile_repo.get_public_by_id(user_id)
        if profile is None:
            raise ProfileNotFoundError(f"User {user_id} not found")
        return profile

    async def get_me_profile(self, user_id: uuid.UUID) -> MeProfile:
        profile = await self._profile_repo.get_me_by_id(user_id)
        if profile is None:
            raise ProfileNotFoundError(f"User {user_id} not found")
        return profile

    async def update_me_profile(self, user_id: uuid.UUID, patch: MeProfilePatch) -> MeProfile:
        _validate_patch(patch)
        normalized = _normalize_patch(patch)
        return await self._profile_repo.update_me(
            user_id,
            username=normalized.username,
            bio=normalized.bio,
            preferred_genres=normalized.preferred_genres,
        )
