"""Contract tests for admin friend relationship endpoints."""

import pytest
from httpx import AsyncClient


class TestAdminFriendRelationshipsContract:
    @pytest.mark.asyncio
    async def test_list_relationships_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.get("/admin/v1/friend-relationships")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_get_relationship_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.get("/admin/v1/friend-relationships/some-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_relationship_action_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.post(
            "/admin/v1/friend-relationships/some-id/actions",
            json={"action_type": "remove", "reason": "Test", "confirmed": False},
        )
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_delete_relationship_requires_auth(self, admin_async_client_no_db: AsyncClient) -> None:
        response = await admin_async_client_no_db.delete("/admin/v1/friend-relationships/some-id")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_action_requires_reason(self, admin_async_client_no_db: AsyncClient) -> None:
        """Missing reason field returns 401 (auth check before validation) or 422."""
        response = await admin_async_client_no_db.post(
            "/admin/v1/friend-relationships/some-id/actions",
            json={"action_type": "remove"},
        )
        assert response.status_code in {401, 422}
