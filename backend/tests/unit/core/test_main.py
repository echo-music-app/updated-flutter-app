from unittest.mock import AsyncMock, patch

import pytest
from httpx import ASGITransport, AsyncClient

from backend.core.config import Settings
from backend.main import create_app, lifespan


@pytest.mark.anyio
async def test_lifespan_disposes_engine(settings: Settings):
    """Cover main.py lines 14-15: lifespan yields and disposes engine."""
    mock_engine = AsyncMock()
    app = create_app(settings)
    with patch("backend.main.get_engine", return_value=mock_engine):
        async with lifespan(app):
            pass  # Simulates the app running
    mock_engine.dispose.assert_awaited_once()


@pytest.mark.anyio
async def test_unhandled_exception_returns_500():
    """Cover main.py line 35: 500 error handler."""
    non_debug_settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@localhost:5432/echo_test",
        secret_key="test-secret-key",
        debug=False,
    )
    app = create_app(non_debug_settings)

    @app.get("/v1/test-500")
    async def crash():
        raise RuntimeError("boom")

    async with AsyncClient(transport=ASGITransport(app=app, raise_app_exceptions=False), base_url="http://test") as client:
        response = await client.get("/v1/test-500")
        assert response.status_code == 500
        assert response.json()["detail"] == "Internal server error"
