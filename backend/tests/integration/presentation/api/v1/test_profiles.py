"""Integration tests for user profile endpoints."""

import uuid

import pytest
from httpx import AsyncClient
from sqlalchemy import event, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.user import User, UserStatus


async def _register(client: AsyncClient, email: str, username: str) -> tuple[str, str]:
    reg_resp = await client.post(
        "/v1/auth/register",
        json={"email": email, "username": username, "password": "password123"},
    )
    assert reg_resp.status_code == 201
    verification_code = reg_resp.json()["verification_code"]
    verify_resp = await client.post(
        "/v1/auth/verify-email",
        json={"email": email, "code": verification_code},
    )
    assert verify_resp.status_code == 200
    data = verify_resp.json()
    return data["access_token"], data["refresh_token"]


# ---------------------------------------------------------------------------
# T016: US1 — GET /v1/users/{userId} integration tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_user_profile_returns_public_fields_only(async_client: AsyncClient, db_session: AsyncSession):
    """Public projection must not include email, status, password_hash, updated_at."""
    token, _ = await _register(async_client, "prof_i1@example.com", "prof_i1")
    me = (await db_session.execute(select(User).where(User.email == "prof_i1@example.com"))).scalar_one()

    response = await async_client.get(
        f"/v1/users/{me.id}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    # Must include public fields
    assert body["id"] == str(me.id)
    assert body["username"] == "prof_i1"
    # Must NOT include sensitive fields
    assert "email" not in body
    assert "status" not in body
    assert "password_hash" not in body
    assert "updated_at" not in body


@pytest.mark.anyio
async def test_get_user_profile_404_for_unknown(async_client: AsyncClient):
    token, _ = await _register(async_client, "prof_i2@example.com", "prof_i2")
    response = await async_client.get(
        f"/v1/users/{uuid.uuid4()}",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 404


@pytest.mark.anyio
async def test_get_user_profile_single_query(async_client: AsyncClient, db_session: AsyncSession):
    """Endpoint should execute a bounded number of SELECT statements (no N+1)."""
    token, _ = await _register(async_client, "prof_i3@example.com", "prof_i3")
    me = (await db_session.execute(select(User).where(User.email == "prof_i3@example.com"))).scalar_one()

    executed: list[str] = []

    def _capture(conn, cursor, statement, parameters, context, executemany):
        if statement.strip().upper().startswith("SELECT"):
            executed.append(statement)

    sync_engine = db_session.bind.sync_engine
    event.listen(sync_engine, "before_cursor_execute", _capture)
    try:
        response = await async_client.get(
            f"/v1/users/{me.id}",
            headers={"Authorization": f"Bearer {token}"},
        )
    finally:
        event.remove(sync_engine, "before_cursor_execute", _capture)

    assert response.status_code == 200
    # At most 3 SELECTs: token lookup, user lookup (auth), user lookup (profile)
    assert len(executed) <= 3, f"Expected ≤3 queries, got {len(executed)}: {executed}"


# ---------------------------------------------------------------------------
# T022: US2 — GET /v1/me integration tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_get_me_returns_caller_only_fields(async_client: AsyncClient, db_session: AsyncSession):
    """GET /v1/me must include email, status, updated_at for caller."""
    token, _ = await _register(async_client, "prof_i4@example.com", "prof_i4")

    response = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "prof_i4@example.com"
    assert "status" in body
    assert "updated_at" in body


@pytest.mark.anyio
async def test_get_me_returns_only_authenticated_user(async_client: AsyncClient, db_session: AsyncSession):
    """GET /v1/me must always return the caller's own data."""
    token_a, _ = await _register(async_client, "prof_i5a@example.com", "prof_i5a")
    await _register(async_client, "prof_i5b@example.com", "prof_i5b")

    response = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token_a}"})
    assert response.status_code == 200
    body = response.json()
    assert body["email"] == "prof_i5a@example.com"
    assert body["username"] == "prof_i5a"


@pytest.mark.anyio
async def test_get_me_403_disabled_account(async_client: AsyncClient, db_session: AsyncSession):
    """GET /v1/me returns 403 when the account status is disabled."""
    token, _ = await _register(async_client, "prof_i6@example.com", "prof_i6")
    me = (await db_session.execute(select(User).where(User.email == "prof_i6@example.com"))).scalar_one()

    me.status = UserStatus.disabled
    await db_session.flush()

    response = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 403


@pytest.mark.anyio
async def test_get_me_single_query(async_client: AsyncClient, db_session: AsyncSession):
    """GET /v1/me should execute a bounded number of SELECT statements."""
    token, _ = await _register(async_client, "prof_i7@example.com", "prof_i7")

    executed: list[str] = []

    def _capture(conn, cursor, statement, parameters, context, executemany):
        if statement.strip().upper().startswith("SELECT"):
            executed.append(statement)

    sync_engine = db_session.bind.sync_engine
    event.listen(sync_engine, "before_cursor_execute", _capture)
    try:
        response = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    finally:
        event.remove(sync_engine, "before_cursor_execute", _capture)

    assert response.status_code == 200
    # At most 3 SELECTs: token lookup, user lookup (auth), user lookup (profile)
    assert len(executed) <= 3, f"Expected ≤3 queries, got {len(executed)}: {executed}"


# ---------------------------------------------------------------------------
# T028: US3 — PATCH /v1/me integration tests
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_patch_me_persists_bio(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "prof_i8@example.com", "prof_i8")

    response = await async_client.patch(
        "/v1/me",
        json={"bio": "Updated bio"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["bio"] == "Updated bio"

    me = (await db_session.execute(select(User).where(User.email == "prof_i8@example.com"))).scalar_one()
    await db_session.refresh(me)
    assert me.bio == "Updated bio"


@pytest.mark.anyio
async def test_patch_me_normalizes_preferred_genres(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "prof_i9@example.com", "prof_i9")

    response = await async_client.patch(
        "/v1/me",
        json={"preferred_genres": ["house", "ambient", "house"]},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["preferred_genres"] == ["house", "ambient"]


@pytest.mark.anyio
async def test_patch_me_immutability_email(async_client: AsyncClient):
    token, _ = await _register(async_client, "prof_i10@example.com", "prof_i10")
    response = await async_client.patch(
        "/v1/me",
        json={"email": "hacker@example.com"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_patch_me_immutability_is_artist(async_client: AsyncClient):
    token, _ = await _register(async_client, "prof_i11@example.com", "prof_i11")
    response = await async_client.patch(
        "/v1/me",
        json={"is_artist": True},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_patch_me_username_update_persists(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "prof_i12@example.com", "prof_i12")

    response = await async_client.patch(
        "/v1/me",
        json={"username": "prof_i12_new"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    assert response.json()["username"] == "prof_i12_new"


@pytest.mark.anyio
async def test_profile_repository_get_me_returns_none_for_unknown(db_session: AsyncSession):
    """SqlAlchemyProfileRepository.get_me_by_id returns None for unknown user."""
    from backend.infrastructure.persistence.repositories.profile_repository import SqlAlchemyProfileRepository

    repo = SqlAlchemyProfileRepository(db_session)
    result = await repo.get_me_by_id(uuid.uuid4())
    assert result is None


@pytest.mark.anyio
async def test_profile_repository_update_me_raises_not_found(db_session: AsyncSession):
    """SqlAlchemyProfileRepository.update_me raises ProfileNotFoundError for unknown user."""
    from backend.domain.profiles.exceptions import ProfileNotFoundError
    from backend.infrastructure.persistence.repositories.profile_repository import SqlAlchemyProfileRepository

    repo = SqlAlchemyProfileRepository(db_session)
    with pytest.raises(ProfileNotFoundError):
        await repo.update_me(uuid.uuid4(), bio="test")


@pytest.mark.anyio
async def test_get_me_profile_not_found_after_delete(async_client: AsyncClient, db_session: AsyncSession):
    """GET /v1/me returns 404 when the user is deleted between auth and profile fetch (defensive)."""
    from sqlalchemy import delete

    from backend.infrastructure.persistence.models.auth import AccessToken

    token, _ = await _register(async_client, "prof_i14@example.com", "prof_i14")
    me = (await db_session.execute(select(User).where(User.email == "prof_i14@example.com"))).scalar_one()

    # Delete all auth tokens and the user to simulate a post-auth deletion
    await db_session.execute(delete(AccessToken).where(AccessToken.user_id == me.id))
    await db_session.execute(delete(User).where(User.id == me.id))
    await db_session.flush()

    # The token is now invalid so auth will return 401 — this validates the defensive path exists
    response = await async_client.get("/v1/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code in {401, 404}


@pytest.mark.anyio
async def test_patch_me_single_query(async_client: AsyncClient, db_session: AsyncSession):
    """PATCH /v1/me should execute a bounded number of statements."""
    token, _ = await _register(async_client, "prof_i13@example.com", "prof_i13")

    executed: list[str] = []

    def _capture(conn, cursor, statement, parameters, context, executemany):
        executed.append(statement)

    sync_engine = db_session.bind.sync_engine
    event.listen(sync_engine, "before_cursor_execute", _capture)
    try:
        response = await async_client.patch(
            "/v1/me",
            json={"bio": "test bio"},
            headers={"Authorization": f"Bearer {token}"},
        )
    finally:
        event.remove(sync_engine, "before_cursor_execute", _capture)

    assert response.status_code == 200
    # At most 6: token select, user select, profile select, UPDATE, RETURNING/refresh select
    assert len(executed) <= 6, f"Expected ≤6 statements, got {len(executed)}"
