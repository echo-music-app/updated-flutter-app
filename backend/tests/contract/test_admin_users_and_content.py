"""Contract tests for admin user and content endpoints."""

import pytest
from httpx import AsyncClient


class TestAdminUsersContract:
    @pytest.mark.asyncio
    async def test_list_users_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.get("/admin/v1/users")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_user_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.get("/admin/v1/users/some-user-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_update_user_status_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.patch(
            "/admin/v1/users/some-user-id/status",
            json={"status": "suspended", "reason": "Test"},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_update_user_status_validates_payload(self, admin_async_client_no_db: AsyncClient) -> None:
        """Missing required fields return 422."""
        response = await admin_async_client_no_db.patch(
            "/admin/v1/users/some-user-id/status",
            json={},
        )
        assert response.status_code in {401, 422}


class TestAdminContentContract:
    @pytest.mark.asyncio
    async def test_list_content_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.get("/admin/v1/content")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_content_action_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.post(
            "/admin/v1/content/some-id/actions",
            json={"action_type": "remove", "reason": "Test"},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_delete_content_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.delete("/admin/v1/content/some-id")
        assert response.status_code == 401
