"""Integration tests for admin authentication endpoints."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import hash_password
from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope


async def create_admin(
    db: AsyncSession,
    *,
    email: str = "admin@example.com",
    password: str = "AdminPassword123!",
    display_name: str = "Test Admin",
    is_active: bool = True,
) -> tuple[AdminAccount, str]:
    """Helper: create an admin account and return (account, raw_password)."""
    account = AdminAccount(
        email=email,
        password_hash=hash_password(password),
        display_name=display_name,
        permission_scope=AdminPermissionScope.full_admin,
        is_active=is_active,
    )
    db.add(account)
    await db.flush()
    await db.refresh(account)
    return account, password


class TestAdminLoginIntegration:
    @pytest.mark.asyncio
    async def test_active_admin_can_sign_in(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """An active admin with correct credentials receives a session token."""
        _, password = await create_admin(db_session)

        response = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )

        assert response.status_code == 200
        body = response.json()
        assert "admin_id" in body
        assert body["status"] == "active"
        assert "permission_scope" in body

    @pytest.mark.asyncio
    async def test_wrong_password_returns_401(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """Wrong password returns 401 Unauthorized."""
        await create_admin(db_session)

        response = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": "wrongpassword"},
        )

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_nonexistent_email_returns_401(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """Unknown email returns 401 (not 404 to avoid enumeration)."""
        response = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "nobody@example.com", "password": "somepassword"},
        )

        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_disabled_admin_cannot_sign_in(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """A disabled admin account is rejected at sign-in."""
        _, password = await create_admin(db_session, is_active=False)

        response = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )

        assert response.status_code == 403

    @pytest.mark.asyncio
    async def test_non_admin_token_rejected_on_admin_routes(
        self, async_client: AsyncClient, admin_async_client: AsyncClient, db_session: AsyncSession
    ) -> None:
        """A regular user token is rejected on admin routes with 403."""
        reg_resp = await async_client.post(
            "/v1/auth/register",
            json={
                "email": "user@example.com",
                "username": "regularuser",
                "password": "userpassword123",
            },
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
    async def test_session_disabled_mid_session(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """An admin account disabled after login has subsequent requests rejected."""
        account, password = await create_admin(db_session)

        login_resp = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        # Disable the admin account
        account.is_active = False
        await db_session.flush()

        # Next request with existing token should be rejected
        session_resp = await admin_async_client.get(
            "/admin/v1/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert session_resp.status_code == 403

    @pytest.mark.asyncio
    async def test_logout_invalidates_token(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """After logout, the same token is rejected."""
        _, password = await create_admin(db_session)

        login_resp = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        logout_resp = await admin_async_client.post(
            "/admin/v1/auth/logout",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert logout_resp.status_code == 200

        # Token is now invalid
        session_resp = await admin_async_client.get(
            "/admin/v1/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert session_resp.status_code == 401

    @pytest.mark.asyncio
    async def test_get_session_returns_admin_info(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """GET /admin/v1/auth/session returns admin session info for a valid token."""
        _, password = await create_admin(db_session)

        login_resp = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        assert login_resp.status_code == 200
        token = login_resp.json()["access_token"]

        session_resp = await admin_async_client.get(
            "/admin/v1/auth/session",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert session_resp.status_code == 200
        body = session_resp.json()
        assert body["email"] == "admin@example.com"
        assert body["status"] == "active"
        assert "admin_id" in body
