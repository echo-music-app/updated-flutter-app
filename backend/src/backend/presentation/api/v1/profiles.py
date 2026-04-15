"""Profiles API adapter - GET /v1/users/{userId}, GET /v1/me, PATCH /v1/me."""

import uuid
from datetime import datetime
from pathlib import Path

from fastapi import APIRouter, Depends, File, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse
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
_ALLOWED_AVATAR_TYPES = {
    "image/jpeg": ".jpg",
    "image/png": ".png",
    "image/webp": ".webp",
}
_MAX_AVATAR_BYTES = 5 * 1024 * 1024
_AVATAR_DIR = Path(__file__).resolve().parents[5] / "uploads" / "avatars"


class PublicUserProfileResponse(BaseModel):
    id: uuid.UUID
    username: str
    avatar_url: str | None
    bio: str | None
    preferred_genres: list[str]
    is_artist: bool
    followers_count: int
    following_count: int
    created_at: datetime


class MeProfileResponse(BaseModel):
    id: uuid.UUID
    email: str
    username: str
    avatar_url: str | None
    bio: str | None
    preferred_genres: list[str]
    status: str
    is_artist: bool
    followers_count: int
    following_count: int
    created_at: datetime
    updated_at: datetime


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


def _get_profile_use_cases(db: AsyncSession = Depends(get_db_session)) -> ProfileUseCases:
    return ProfileUseCases(profile_repo=SqlAlchemyProfileRepository(db))


def _avatar_url(user_id: uuid.UUID, avatar_path: str | None) -> str | None:
    if not avatar_path:
        return None
    return f"/v1/users/{user_id}/avatar"


def _to_public_response(profile: PublicUserProfile) -> PublicUserProfileResponse:
    return PublicUserProfileResponse(
        id=profile.id,
        username=profile.username,
        avatar_url=_avatar_url(profile.id, profile.avatar_path),
        bio=profile.bio,
        preferred_genres=profile.preferred_genres,
        is_artist=profile.is_artist,
        followers_count=profile.followers_count,
        following_count=profile.following_count,
        created_at=profile.created_at,
    )


def _to_me_response(profile: MeProfile) -> MeProfileResponse:
    return MeProfileResponse(
        id=profile.id,
        email=profile.email,
        username=profile.username,
        avatar_url=_avatar_url(profile.id, profile.avatar_path),
        bio=profile.bio,
        preferred_genres=profile.preferred_genres,
        status=profile.status,
        is_artist=profile.is_artist,
        followers_count=profile.followers_count,
        following_count=profile.following_count,
        created_at=profile.created_at,
        updated_at=profile.updated_at,
    )


@router.get("/users/search", response_model=list[PublicUserProfileResponse])
async def search_users(
    q: str = Query(..., min_length=1, max_length=50),
    limit: int = Query(default=20, ge=1, le=50),
    current_user: User = Depends(get_current_user),
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    profiles = await use_cases.search_users(
        q,
        limit=limit,
        exclude_user_id=current_user.id,
    )
    return [_to_public_response(profile) for profile in profiles]


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


@router.post("/me/avatar", response_model=MeProfileResponse)
async def upload_me_avatar(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    extension = _ALLOWED_AVATAR_TYPES.get(file.content_type or "")
    if extension is None:
        raise HTTPException(status_code=415, detail="Unsupported avatar type. Use jpg, png, or webp.")

    content = await file.read()
    if not content:
        raise HTTPException(status_code=422, detail="Avatar file is empty.")
    if len(content) > _MAX_AVATAR_BYTES:
        raise HTTPException(status_code=413, detail="Avatar file too large (max 5 MB).")

    _AVATAR_DIR.mkdir(parents=True, exist_ok=True)
    filename = f"{current_user.id}{extension}"
    output_path = _AVATAR_DIR / filename
    output_path.write_bytes(content)

    profile = await use_cases.update_me_avatar(current_user.id, avatar_path=filename)
    return _to_me_response(profile)


@router.get("/users/{userId}/avatar")
async def get_user_avatar(
    userId: uuid.UUID,
    use_cases: ProfileUseCases = Depends(_get_profile_use_cases),
):
    try:
        profile = await use_cases.get_user_profile(userId)
    except ProfileNotFoundError:
        raise HTTPException(status_code=404, detail="User not found")

    if not profile.avatar_path:
        raise HTTPException(status_code=404, detail="Avatar not found")

    avatar_root = _AVATAR_DIR.resolve()
    file_path = (_AVATAR_DIR / profile.avatar_path).resolve()
    if not file_path.is_relative_to(avatar_root):
        raise HTTPException(status_code=404, detail="Avatar not found")
    if not file_path.exists():
        raise HTTPException(status_code=404, detail="Avatar not found")

    return FileResponse(file_path)
