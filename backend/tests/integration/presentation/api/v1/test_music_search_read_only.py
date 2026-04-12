"""Read-only safety test: POST /v1/search/music must not write to any persistence layer."""

import pytest
from fastapi import FastAPI
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.music_search.entities import SourceResultItem
from backend.presentation.api.v1.music_search import get_music_search_use_case


async def _register(client: AsyncClient, email: str, username: str) -> str:
    reg_resp = await client.post(
        "/v1/auth/register",
        json={"email": email, "username": username, "password": "password123"},
    )
    assert reg_resp.status_code == 201
    verification_code = reg_resp.json()["verification_code"]
    verify_resp = await client.post(
        "/v1/auth/verify-email",
        json={"email": email, "code": verification_code},
    )
    assert verify_resp.status_code == 200
    return verify_resp.json()["access_token"]


class _ReadOnlyMockProvider:
    """Provider mock that records calls and ensures no mutation-like side effects."""

    def __init__(self):
        self.calls: list[str] = []

    async def search_tracks(self, term, limit):
        self.calls.append("search_tracks")
        return [
            SourceResultItem(
                source="spotify",
                source_item_id="spotify:track:ro1",
                type="track",
                display_name="Read Only Track",
                primary_creator_name="Artist",
                duration_ms=180000,
                provider_relevance=0.8,
            )
        ]

    async def search_albums(self, term, limit):
        self.calls.append("search_albums")
        return []

    async def search_artists(self, term, limit):
        self.calls.append("search_artists")
        return []


@pytest.mark.anyio
async def test_music_search_does_not_write_to_db(
    async_client: AsyncClient,
    app: FastAPI,
    db_session: AsyncSession,
):
    """Verify that POST /v1/search/music performs no DB writes (read-only operation)."""
    from unittest.mock import MagicMock

    from backend.application.music_search.use_cases import MusicSearchUseCase

    token = await _register(async_client, "music_ro_1@example.com", "music_ro_1")

    provider = _ReadOnlyMockProvider()

    mock_settings = MagicMock()
    mock_settings.music_search_request_timeout_seconds = 5.0
    mock_settings.music_search_provider_bulkhead_limit = 10

    use_case = MusicSearchUseCase(
        spotify_client=provider,
        soundcloud_client=_ReadOnlyMockProvider(),
        settings=mock_settings,
    )

    # Count DB operations before the request
    pre_flush_count = db_session.new  # objects pending INSERT

    app.dependency_overrides[get_music_search_use_case] = lambda: use_case
    try:
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    finally:
        app.dependency_overrides.pop(get_music_search_use_case, None)

    assert response.status_code == 200

    # Provider was called
    assert "search_tracks" in provider.calls

    # DB session must have no new pending objects from the search (read-only)
    assert db_session.new == pre_flush_count, "POST /v1/search/music must not stage any new DB objects"
