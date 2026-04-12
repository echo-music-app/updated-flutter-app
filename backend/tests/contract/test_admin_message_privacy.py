"""Contract tests for admin message privacy boundary.

Verifies that NO message-management endpoints exist under /admin/v1.
"""

import pytest
from httpx import AsyncClient


class TestAdminMessagePrivacyContract:
    """All message-related admin endpoints must not exist or must return 404/405."""

    @pytest.mark.asyncio
    async def test_no_message_list_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """GET /admin/v1/messages must not exist."""
        response = await admin_async_client_no_db.get("/admin/v1/messages")
        assert response.status_code in {404, 405}

    @pytest.mark.asyncio
    async def test_no_message_search_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """No message search endpoint under admin."""
        response = await admin_async_client_no_db.get("/admin/v1/messages/search")
        assert response.status_code in {404, 405}

    @pytest.mark.asyncio
    async def test_no_message_delete_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """No message delete endpoint under admin."""
        response = await admin_async_client_no_db.delete("/admin/v1/messages/some-id")
        assert response.status_code in {404, 405}

    @pytest.mark.asyncio
    async def test_no_message_export_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """No message export endpoint under admin."""
        response = await admin_async_client_no_db.get("/admin/v1/messages/export")
        assert response.status_code in {404, 405}

    @pytest.mark.asyncio
    async def test_no_message_restore_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """No message restore endpoint under admin."""
        response = await admin_async_client_no_db.post("/admin/v1/messages/some-id/restore")
        assert response.status_code in {404, 405}

    @pytest.mark.asyncio
    async def test_no_message_thread_endpoint(self, admin_async_client_no_db: AsyncClient) -> None:
        """No message thread endpoint under admin."""
        response = await admin_async_client_no_db.get("/admin/v1/message-threads")
        assert response.status_code in {404, 405}
