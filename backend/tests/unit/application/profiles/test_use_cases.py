"""Unit tests for profile use cases."""

import uuid
from unittest.mock import AsyncMock

import pytest

from backend.application.profiles.use_cases import ProfileUseCases, _normalize_patch, _validate_patch
from backend.domain.profiles.entities.profile import MeProfile, MeProfilePatch, PublicUserProfile
from backend.domain.profiles.exceptions import (
    InvalidProfilePatchError,
    ProfileNotFoundError,
    UsernameConflictError,
)

# ---------------------------------------------------------------------------
# T014: Patch payload validation rules (foundational, must fail before impl)
# ---------------------------------------------------------------------------


def test_validate_patch_empty_raises():
    with pytest.raises(InvalidProfilePatchError, match="At least one mutable field"):
        _validate_patch(MeProfilePatch())


def test_validate_patch_username_too_short():
    with pytest.raises(InvalidProfilePatchError, match="between 3 and 50"):
        _validate_patch(MeProfilePatch(username="ab"))


def test_validate_patch_username_too_long():
    with pytest.raises(InvalidProfilePatchError, match="between 3 and 50"):
        _validate_patch(MeProfilePatch(username="a" * 51))


def test_validate_patch_username_invalid_chars():
    with pytest.raises(InvalidProfilePatchError, match="invalid characters"):
        _validate_patch(MeProfilePatch(username="bad name!"))


def test_validate_patch_bio_too_long():
    with pytest.raises(InvalidProfilePatchError, match="at most 200"):
        _validate_patch(MeProfilePatch(bio="x" * 201))


def test_validate_patch_genres_empty_string():
    with pytest.raises(InvalidProfilePatchError, match="non-empty strings"):
        _validate_patch(MeProfilePatch(preferred_genres=["house", ""]))


def test_validate_patch_valid_username():
    _validate_patch(MeProfilePatch(username="alice_music"))


def test_validate_patch_valid_bio():
    _validate_patch(MeProfilePatch(bio="A short bio"))


def test_validate_patch_valid_genres():
    _validate_patch(MeProfilePatch(preferred_genres=["house", "ambient"]))


def test_normalize_patch_deduplicates_genres():
    patch = MeProfilePatch(preferred_genres=["house", "ambient", "house"])
    normalized = _normalize_patch(patch)
    assert normalized.preferred_genres == ["house", "ambient"]


def test_normalize_patch_preserves_order():
    patch = MeProfilePatch(preferred_genres=["jazz", "blues", "jazz", "rock"])
    normalized = _normalize_patch(patch)
    assert normalized.preferred_genres == ["jazz", "blues", "rock"]


# ---------------------------------------------------------------------------
# T017: US1 — get_user_profile use-case unit tests
# ---------------------------------------------------------------------------


def _make_public_profile(user_id: uuid.UUID | None = None) -> PublicUserProfile:
    import datetime

    return PublicUserProfile(
        id=user_id or uuid.uuid4(),
        username="alice",
        avatar_path=None,
        bio="Producer",
        preferred_genres=["house"],
        is_artist=True,
        followers_count=0,
        following_count=0,
        created_at=datetime.datetime(2026, 1, 1, tzinfo=datetime.UTC),
    )


@pytest.mark.anyio
async def test_get_user_profile_returns_public_profile():
    repo = AsyncMock()
    user_id = uuid.uuid4()
    expected = _make_public_profile(user_id)
    repo.get_public_by_id.return_value = expected

    use_cases = ProfileUseCases(profile_repo=repo)
    result = await use_cases.get_user_profile(user_id)

    assert result == expected
    repo.get_public_by_id.assert_called_once_with(user_id)


@pytest.mark.anyio
async def test_get_user_profile_not_found_raises():
    repo = AsyncMock()
    repo.get_public_by_id.return_value = None

    use_cases = ProfileUseCases(profile_repo=repo)
    with pytest.raises(ProfileNotFoundError):
        await use_cases.get_user_profile(uuid.uuid4())


# ---------------------------------------------------------------------------
# T023: US2 — get_me_profile use-case unit tests
# ---------------------------------------------------------------------------


def _make_me_profile(user_id: uuid.UUID | None = None) -> MeProfile:
    import datetime

    uid = user_id or uuid.uuid4()
    return MeProfile(
        id=uid,
        email="alice@example.com",
        username="alice",
        avatar_path=None,
        bio="Producer",
        preferred_genres=["house"],
        status="active",
        is_artist=True,
        followers_count=0,
        following_count=0,
        created_at=datetime.datetime(2026, 1, 1, tzinfo=datetime.UTC),
        updated_at=datetime.datetime(2026, 1, 2, tzinfo=datetime.UTC),
    )


@pytest.mark.anyio
async def test_get_me_profile_returns_me_profile():
    repo = AsyncMock()
    user_id = uuid.uuid4()
    expected = _make_me_profile(user_id)
    repo.get_me_by_id.return_value = expected

    use_cases = ProfileUseCases(profile_repo=repo)
    result = await use_cases.get_me_profile(user_id)

    assert result == expected
    repo.get_me_by_id.assert_called_once_with(user_id)


@pytest.mark.anyio
async def test_get_me_profile_not_found_raises():
    repo = AsyncMock()
    repo.get_me_by_id.return_value = None

    use_cases = ProfileUseCases(profile_repo=repo)
    with pytest.raises(ProfileNotFoundError):
        await use_cases.get_me_profile(uuid.uuid4())


# ---------------------------------------------------------------------------
# T029: US3 — update_me_profile use-case unit tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_update_me_profile_calls_repo_with_normalized_genres():
    repo = AsyncMock()
    user_id = uuid.uuid4()
    expected = _make_me_profile(user_id)
    repo.update_me.return_value = expected

    use_cases = ProfileUseCases(profile_repo=repo)
    patch = MeProfilePatch(preferred_genres=["house", "ambient", "house"])
    result = await use_cases.update_me_profile(user_id, patch)

    assert result == expected
    call_kwargs = repo.update_me.call_args
    assert call_kwargs.kwargs["preferred_genres"] == ["house", "ambient"]


@pytest.mark.anyio
async def test_update_me_profile_empty_patch_raises():
    repo = AsyncMock()
    use_cases = ProfileUseCases(profile_repo=repo)

    with pytest.raises(InvalidProfilePatchError):
        await use_cases.update_me_profile(uuid.uuid4(), MeProfilePatch())


@pytest.mark.anyio
async def test_update_me_profile_propagates_username_conflict():
    repo = AsyncMock()
    repo.update_me.side_effect = UsernameConflictError("taken")

    use_cases = ProfileUseCases(profile_repo=repo)
    patch = MeProfilePatch(username="taken_name")
    with pytest.raises(UsernameConflictError):
        await use_cases.update_me_profile(uuid.uuid4(), patch)


# ---------------------------------------------------------------------------
# Endpoint-level coverage: ProfileNotFoundError in get_me endpoint
# (defensive guard — authenticated user could be deleted between auth and profile fetch)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_me_endpoint_returns_404_on_profile_not_found():
    """GET /v1/me returns 404 when the use case raises ProfileNotFoundError (defensive guard)."""
    import uuid

    from httpx import ASGITransport, AsyncClient

    from backend.application.profiles.use_cases import ProfileUseCases
    from backend.core.config import Settings
    from backend.core.deps import get_current_user
    from backend.infrastructure.persistence.models.user import User, UserStatus
    from backend.main import create_app
    from backend.presentation.api.v1.profiles import _get_profile_use_cases

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@localhost:5432/echo",
        secret_key="test-secret",
        debug=True,
        spotify_token_encryption_key="a" * 64,
    )
    app = create_app(settings)

    fake_user = User(
        id=uuid.uuid4(),
        email="ghost@example.com",
        username="ghost",
        password_hash="x",
        status=UserStatus.active,
    )

    async def _fake_current_user():
        return fake_user

    fake_use_cases = AsyncMock(spec=ProfileUseCases)
    fake_use_cases.get_me_profile.side_effect = ProfileNotFoundError("gone")

    def _fake_use_cases():
        return fake_use_cases

    app.dependency_overrides[get_current_user] = _fake_current_user
    app.dependency_overrides[_get_profile_use_cases] = _fake_use_cases

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        response = await client.get("/v1/me")

    assert response.status_code == 404
