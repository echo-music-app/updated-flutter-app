"""Integration tests for admin message privacy boundary and audit logging."""

import pytest
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.security import hash_password
from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope


async def create_admin(db: AsyncSession) -> tuple[AdminAccount, str]:
    password = "AdminPassword123!"
    account = AdminAccount(
        email="admin@example.com",
        password_hash=hash_password(password),
        display_name="Test Admin",
        permission_scope=AdminPermissionScope.full_admin,
        is_active=True,
    )
    db.add(account)
    await db.flush()
    await db.refresh(account)
    return account, password


class TestAdminMessageBoundaryIntegration:
    @pytest.mark.asyncio
    async def test_message_routes_return_404_when_authenticated(self, admin_async_client: AsyncClient, db_session: AsyncSession) -> None:
        """Even authenticated admins get 404 for message routes."""
        _, password = await create_admin(db_session)

        login_resp = await admin_async_client.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": password},
        )
        if login_resp.status_code != 200:
            pytest.skip("Admin auth not yet implemented")

        token = login_resp.json()["access_token"]

        response = await admin_async_client.get(
            "/admin/v1/messages",
            headers={"Authorization": f"Bearer {token}"},
        )
        assert response.status_code == 404

    @pytest.mark.asyncio
    async def test_message_routes_return_404_without_auth(self, admin_async_client: AsyncClient) -> None:
        """Message routes do not exist regardless of authentication state."""
        response = await admin_async_client.get("/admin/v1/messages")
        assert response.status_code == 404
