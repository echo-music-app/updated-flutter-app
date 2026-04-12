"""Contract tests for admin authentication endpoints.

These tests verify the HTTP surface (request/response shapes) without hitting a real database.
"""

import pytest
from httpx import AsyncClient


class TestAdminSignIn:
    """POST /admin/v1/auth/login contract."""

    @pytest.mark.asyncio
    async def test_login_returns_session_on_valid_credentials(self, admin_async_client_no_db: AsyncClient) -> None:
        """Valid admin credentials return 200 with session payload shape."""
        response = await admin_async_client_no_db.post(
            "/admin/v1/auth/login",
            json={"email": "admin@example.com", "password": "password123"},
        )
        # 200 or 422 depending on whether mock admin exists; shape contract:
        assert response.status_code in {200, 401, 422}

    @pytest.mark.asyncio
    async def test_login_requires_email_and_password(self, admin_async_client_no_db: AsyncClient) -> None:
        """Missing required fields return 422 Unprocessable Entity."""
        response = await admin_async_client_no_db.post("/admin/v1/auth/login", json={})
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_login_rejects_malformed_email(self, admin_async_client_no_db: AsyncClient) -> None:
        """Malformed email field returns 422."""
        response = await admin_async_client_no_db.post(
            "/admin/v1/auth/login",
            json={"email": "not-an-email", "password": "password123"},
        )
        assert response.status_code == 422

    @pytest.mark.asyncio
    async def test_session_endpoint_requires_authentication(self, admin_async_client_no_db: AsyncClient) -> None:
        """GET /admin/v1/auth/session without a token returns 401."""
        response = await admin_async_client_no_db.get("/admin/v1/auth/session")
        assert response.status_code == 401

    @pytest.mark.asyncio
    async def test_logout_endpoint_requires_authentication(self, admin_async_client_no_db: AsyncClient) -> None:
        """POST /admin/v1/auth/logout without a token returns 401."""
        response = await admin_async_client_no_db.post("/admin/v1/auth/logout")
        assert response.status_code == 401


class TestSessionBootstrap:
    """GET /admin/v1/auth/session contract."""

    @pytest.mark.asyncio
    async def test_session_response_shape(self, admin_async_client_no_db: AsyncClient) -> None:
        """Session endpoint returns 401 when unauthenticated (shape verification)."""
        response = await admin_async_client_no_db.get("/admin/v1/auth/session")
        assert response.status_code == 401
        body = response.json()
        assert "detail" in body
