import pytest
from httpx import AsyncClient


@pytest.mark.anyio
async def test_health_returns_200(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/health")
    assert response.status_code == 200


@pytest.mark.anyio
async def test_health_response_body(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/health")
    assert response.json() == {"status": "ok", "version": "0.1.0"}


@pytest.mark.anyio
async def test_health_no_auth_required(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/health")
    assert response.status_code == 200
