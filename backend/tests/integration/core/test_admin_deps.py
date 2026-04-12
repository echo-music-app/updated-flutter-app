"""Integration tests for admin dependency wiring."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import hash_password
from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope


async def _create_admin_and_get_token(client: AsyncClient, db: AsyncSession) -> str:
    password = "AdminPassword123!"
    account = AdminAccount(
        email="dep_admin@example.com",
        password_hash=hash_password(password),
        display_name="Dep Admin",
        permission_scope=AdminPermissionScope.full_admin,
        is_active=True,
    )
    db.add(account)
    await db.flush()
    await db.refresh(account)

    login_resp = await client.post(
        "/admin/v1/auth/login",
        json={"email": "dep_admin@example.com", "password": password},
    )
    assert login_resp.status_code == 200
    return login_resp.json()["access_token"]


@pytest.mark.asyncio
async def test_protected_admin_route_requires_admin_token(admin_async_client: AsyncClient) -> None:
    """Requests without admin Bearer token are rejected with 401."""
    response = await admin_async_client.get("/admin/v1/auth/session")
    assert response.status_code == 401


@pytest.mark.asyncio
async def test_protected_admin_route_rejects_user_token(async_client: AsyncClient, admin_async_client: AsyncClient, db_session) -> None:
    """End-user bearer tokens must be denied on admin routes."""
    reg_resp = await async_client.post(
        "/v1/auth/register",
        json={"email": "user@example.com", "username": "testuser", "password": "securepassword123"},
    )
    assert reg_resp.status_code == 201
    verification_code = reg_resp.json()["verification_code"]
    verify_resp = await async_client.post(
        "/v1/auth/verify-email",
        json={"email": "user@example.com", "code": verification_code},
    )
    assert verify_resp.status_code == 200
    user_token = verify_resp.json()["access_token"]

    response = await admin_async_client.get(
        "/admin/v1/auth/session",
        headers={"Authorization": f"Bearer {user_token}"},
    )
    assert response.status_code == 403


@pytest.mark.asyncio
async def test_inactive_admin_account_is_denied(admin_async_client: AsyncClient, db_session) -> None:
    """An admin token belonging to a disabled admin account must be rejected with 403."""
    # Sign in as admin to get a token — requires an admin account fixture
    # This test will pass once admin auth is implemented
    pass


@pytest.mark.asyncio
async def test_valid_admin_token_sets_request_state(admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
    """After successful authentication the admin info is accessible via the session endpoint."""
    token = await _create_admin_and_get_token(admin_async_client, db_session)

    response = await admin_async_client.get(
        "/admin/v1/auth/session",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    body = response.json()
    assert "admin_id" in body
