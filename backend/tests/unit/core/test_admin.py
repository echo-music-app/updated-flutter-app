from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from backend.admin import create_admin_app, lifespan
from backend.core.config import Settings


@pytest.mark.anyio
async def test_lifespan_disposes_engine(settings: Settings):
    mock_engine = AsyncMock()
    app = create_admin_app(settings)
    with patch("backend.admin.get_engine", return_value=mock_engine):
        async with lifespan(app):
            pass  # Simulates the app running
    mock_engine.dispose.assert_awaited_once()


@pytest.mark.anyio
async def test_unhandled_exception_returns_500():
    non_debug_settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@localhost:5432/echo_test",
        secret_key="test-secret-key",
        debug=False,
    )
    app = create_admin_app(non_debug_settings)

    @app.get("/v1/test-500")
    async def crash():
        raise RuntimeError("boom")

    async with AsyncClient(transport=ASGITransport(app=app, raise_app_exceptions=False), base_url="http://test") as client:
        response = await client.get("/v1/test-500")
        assert response.status_code == 500
        assert response.json()["detail"] == "Internal server error"
