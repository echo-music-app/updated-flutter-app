import pytest
from httpx import AsyncClient


class TestWellKnownEndpoints:
    @pytest.mark.asyncio
    async def test_asset_links_returns_200(self, async_client_no_db: AsyncClient):
        """GET /.well-known/assetlinks.json returns 200 with list payload."""
        response = await async_client_no_db.get("/.well-known/assetlinks.json")
        assert response.status_code == 200
        assert isinstance(response.json(), list)

    @pytest.mark.asyncio
    async def test_apple_app_site_association_returns_200(self, async_client_no_db: AsyncClient):
        """GET /.well-known/apple-app-site-association returns 200 with applinks payload."""
        response = await async_client_no_db.get("/.well-known/apple-app-site-association")
        assert response.status_code == 200
        assert "applinks" in response.json()
