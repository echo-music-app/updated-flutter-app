"""Profiles API adapter — GET /v1/users/{userId}, GET /v1/me, PATCH /v1/me."""

import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field, model_validator
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.profiles.use_cases import ProfileUseCases
from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.domain.profiles.entities.profile import MeProfile, MeProfilePatch, PublicUserProfile
from backend.domain.profiles.exceptions import InvalidProfilePatchError, ProfileNotFoundError, UsernameConflictError
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.profile_repository import SqlAlchemyProfileRepository

router = APIRouter(tags=["profiles"])

_NON_MUTABLE_FIELD_NAMES = {"email", "status", "password_hash", "is_artist"}


# ---------------------------------------------------------------------------
# Response models
# ---------------------------------------------------------------------------


class PublicUserProfileResponse(BaseModel):
    id: uuid.UUID
    username: str
    bio: str | None
    preferred_genres: list[str]
    is_artist: bool
    created_at: datetime


class MeProfileResponse(BaseModel):
    id: uuid.UUID
    email: str
    username: str
    bio: str | None
    preferred_genres: list[str]
    status: str
    is_artist: bool
    created_at: datetime
    updated_at: datetime


# ---------------------------------------------------------------------------
# Request model
# ---------------------------------------------------------------------------


class PatchMeRequest(BaseModel):
    username: str | None = Field(default=None)
    bio: str | None = Field(default=None)
    preferred_genres: list[str] | None = Field(default=None)

    @model_validator(mode="before")
    @classmethod
    def reject_non_mutable_fields(cls, values: dict) -> dict:
        if isinstance(values, dict):
            bad = _NON_MUTABLE_FIELD_NAMES & set(values.keys())
            if bad:
                raise ValueError(f"Fields not allowed in PATCH /v1/me: {', '.join(sorted(bad))}")
        return values


# ---------------------------------------------------------------------------
# Dependency factory
# ---------------------------------------------------------------------------


def _get_profile_use_cases(db: AsyncSession = Depends(get_db_session)) -> ProfileUseCases:
    return ProfileUseCases(profile_repo=SqlAlchemyProfileRepository(db))


# ---------------------------------------------------------------------------
# Response mappers
# ---------------------------------------------------------------------------


def _to_public_response(profile: PublicUserProfile) -> PublicUserProfileResponse:
    return PublicUserProfileResponse(
        id=profile.id,
        username=profile.username,
        bio=profile.bio,
        preferred_genres=profile.preferred_genres,
        is_artist=profile.is_artist,
        created_at=profile.created_at,
    )


def _to_me_response(profile: MeProfile) -> MeProfileResponse:
    return MeProfileResponse(
        id=profile.id,
        email=profile.email,
        username=profile.username,
        bio=profile.bio,
        preferred_genres=profile.preferred_genres,
        status=profile.status,
        is_artist=profile.is_artist,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------


@router.get("/users/{userId}", response_model=PublicUserProfileResponse)
async def get_user_profile(
    userId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    try:
        profile = await use_cases.get_user_profile(userId)
    except ProfileNotFoundError:
        raise HTTPException(status_code=404, detail="User not found")
    return _to_public_response(profile)


@router.get("/me", response_model=MeProfileResponse)
async def get_me_profile(
    current_user: User = Depends(get_current_user),
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    try:
        profile = await use_cases.get_me_profile(current_user.id)
    except ProfileNotFoundError:
        raise HTTPException(status_code=404, detail="User not found")
    return _to_me_response(profile)


@router.patch("/me", response_model=MeProfileResponse)
async def patch_me_profile(
    body: PatchMeRequest,
    current_user: User = Depends(get_current_user),
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    patch = MeProfilePatch(
        username=body.username,
        bio=body.bio,
        preferred_genres=body.preferred_genres,
    )
    try:
        profile = await use_cases.update_me_profile(current_user.id, patch)
    except InvalidProfilePatchError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc
    except UsernameConflictError as exc:
        raise HTTPException(status_code=409, detail=str(exc)) from exc
    return _to_me_response(profile)
