"""Tests for presentation/api/v1/spotify_auth.py and tracks.py — /v1/auth/spotify/* and /v1/tracks/* endpoints."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.domain.auth.entities import TokenPair
from backend.domain.spotify.entities import TrackResponse
from backend.domain.spotify.exceptions import SpotifyApiError, SpotifyAuthError
from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


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


# ---------------------------------------------------------------------------
# POST /v1/auth/spotify/token — unauthenticated / validation
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_spotify_token_no_auth_returns_401(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post("/v1/auth/spotify/token", json={})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_spotify_token_invalid_body_no_auth_returns_401(async_client_no_db: AsyncClient):
    """Auth guard runs before body validation for unauthenticated requests."""
    response = await async_client_no_db.post(
        "/v1/auth/spotify/token",
        json={"code": "", "code_verifier": "", "redirect_uri": "not-a-url"},
    )
    assert response.status_code == 401


@pytest.mark.anyio
async def test_spotify_token_endpoint_exists(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post(
        "/v1/auth/spotify/token",
        json={"code": "x", "code_verifier": "x" * 43, "redirect_uri": "https://example.com/callback"},
    )
    assert response.status_code != 404


# ---------------------------------------------------------------------------
# POST /v1/auth/spotify/token — authenticated / validation
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_spotify_token_code_verifier_too_short(async_client: AsyncClient):
    token = await _register(async_client, "cv1@t.com", "cv1user")
    resp = await async_client.post(
        "/v1/auth/spotify/token",
        json={"code": "x", "code_verifier": "short", "redirect_uri": "https://x.com"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_spotify_token_redirect_uri_not_https(async_client: AsyncClient):
    token = await _register(async_client, "cv2@t.com", "cv2user")
    resp = await async_client.post(
        "/v1/auth/spotify/token",
        json={"code": "x", "code_verifier": "x" * 43, "redirect_uri": "http://insecure.com"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 422


@pytest.mark.anyio
async def test_spotify_token_auth_error_returns_401(async_client: AsyncClient):
    token = await _register(async_client, "cv3@t.com", "cv3user")
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.exchange_code",
        new_callable=AsyncMock,
        side_effect=SpotifyAuthError("bad code"),
    ):
        resp = await async_client.post(
            "/v1/auth/spotify/token",
            json={"code": "bad", "code_verifier": "x" * 43, "redirect_uri": "https://x.com"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 401


@pytest.mark.anyio
async def test_spotify_token_generic_exception_returns_503(async_client: AsyncClient):
    token = await _register(async_client, "cv4@t.com", "cv4user")
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.exchange_code",
        new_callable=AsyncMock,
        side_effect=RuntimeError("boom"),
    ):
        resp = await async_client.post(
            "/v1/auth/spotify/token",
            json={"code": "x", "code_verifier": "x" * 43, "redirect_uri": "https://x.com"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 503


@pytest.mark.anyio
async def test_spotify_token_success(async_client: AsyncClient):
    token = await _register(async_client, "cv5@t.com", "cv5user")
    fake_pair = TokenPair(access_token="new_at", refresh_token="new_rt", expires_in=900)
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.exchange_code",
        new_callable=AsyncMock,
        return_value=fake_pair,
    ):
        resp = await async_client.post(
            "/v1/auth/spotify/token",
            json={"code": "x", "code_verifier": "x" * 43, "redirect_uri": "https://x.com"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert resp.status_code == 200
    assert resp.json()["access_token"] == "new_at"


# ---------------------------------------------------------------------------
# POST /v1/auth/spotify/token — full integration with mocked Spotify API
# ---------------------------------------------------------------------------


@pytest.fixture
def mock_spotify_api():
    mock_token_resp = MagicMock()
    mock_token_resp.status_code = 200
    mock_token_resp.json.return_value = {
        "access_token": "spotify_at_test",
        "refresh_token": "spotify_rt_test",
        "expires_in": 3600,
        "scope": "user-read-private streaming",
    }
    mock_token_resp.raise_for_status = MagicMock()

    mock_user_resp = MagicMock()
    mock_user_resp.status_code = 200
    mock_user_resp.json.return_value = {"id": "spotify_user_42"}
    mock_user_resp.raise_for_status = MagicMock()

    mock_client = AsyncMock()
    mock_client.post.return_value = mock_token_resp
    mock_client.get.return_value = mock_user_resp
    return mock_client


@pytest.mark.anyio
async def test_spotify_full_auth_flow(async_client: AsyncClient, db_session: AsyncSession, mock_spotify_api):
    """Full auth: register → exchange code → get Echo tokens."""
    access_token = await _register(async_client, "spotify@test.com", "spotifyuser")

    with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
        MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_spotify_api)
        MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
        resp = await async_client.post(
            "/v1/auth/spotify/token",
            json={"code": "test_auth_code", "code_verifier": "x" * 43, "redirect_uri": "https://example.com/callback"},
            headers={"Authorization": f"Bearer {access_token}"},
        )

    assert resp.status_code == 200
    data = resp.json()
    assert "access_token" in data
    assert "refresh_token" in data
    assert data["token_type"] == "bearer"


@pytest.mark.anyio
async def test_spotify_upsert_on_reauth(async_client: AsyncClient, db_session: AsyncSession, mock_spotify_api):
    """Re-auth by same Spotify user updates, not duplicates, credentials."""
    access_token = await _register(async_client, "reauth@test.com", "reauthuser")

    for _ in range(2):
        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_spotify_api)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            await async_client.post(
                "/v1/auth/spotify/token",
                json={"code": "test_auth_code", "code_verifier": "x" * 43, "redirect_uri": "https://example.com/callback"},
                headers={"Authorization": f"Bearer {access_token}"},
            )

    result = await db_session.execute(select(SpotifyCredentials).where(SpotifyCredentials.spotify_user_id == "spotify_user_42"))
    assert len(result.scalars().all()) == 1


# ---------------------------------------------------------------------------
# POST /v1/auth/spotify/refresh
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_spotify_refresh_endpoint_exists(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post("/v1/auth/spotify/refresh", json={"refresh_token": "echo_rt_test"})
    assert response.status_code != 404


@pytest.mark.anyio
async def test_spotify_refresh_invalid_token_returns_401(async_client: AsyncClient):
    response = await async_client.post("/v1/auth/spotify/refresh", json={"refresh_token": "echo_rt_invalid"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_spotify_refresh_success(async_client_no_db: AsyncClient):
    fake_pair = TokenPair(access_token="ref_at", refresh_token="ref_rt", expires_in=900)
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.refresh_token",
        new_callable=AsyncMock,
        return_value=fake_pair,
    ):
        resp = await async_client_no_db.post("/v1/auth/spotify/refresh", json={"refresh_token": "valid_rt"})
    assert resp.status_code == 200
    assert resp.json()["access_token"] == "ref_at"


@pytest.mark.anyio
async def test_spotify_refresh_generic_exception_returns_503(async_client_no_db: AsyncClient):
    """A generic unexpected error in the refresh endpoint returns 503."""
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.refresh_token",
        new_callable=AsyncMock,
        side_effect=RuntimeError("unexpected error"),
    ):
        resp = await async_client_no_db.post("/v1/auth/spotify/refresh", json={"refresh_token": "some_rt"})
    assert resp.status_code == 503


# ---------------------------------------------------------------------------
# GET /v1/tracks/{track_id}
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_tracks_no_auth_returns_401(async_client_no_db: AsyncClient):
    response = await async_client_no_db.get("/v1/tracks/4iV5W9uYEdYUVa79Axb7Rh")
    assert response.status_code == 401


@pytest.mark.anyio
async def test_tracks_success(async_client: AsyncClient):
    token = await _register(async_client, "trackuser@t.com", "trackuser")
    fake_track = TrackResponse(
        id="abc",
        uri="spotify:track:abc",
        name="Test Track",
        artist_name="The Artist",
        album_art_url="https://art.jpg",
        duration_ms=3000,
    )
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.get_track",
        new_callable=AsyncMock,
        return_value=fake_track,
    ):
        resp = await async_client.get("/v1/tracks/abc", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["id"] == "abc"


@pytest.mark.anyio
async def test_tracks_api_error_forwarded(async_client: AsyncClient):
    token = await _register(async_client, "trackerr@t.com", "trackerr")
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.get_track",
        new_callable=AsyncMock,
        side_effect=SpotifyApiError(404, "Track not found"),
    ):
        resp = await async_client.get("/v1/tracks/missing", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 404


@pytest.mark.anyio
async def test_tracks_generic_exception_returns_503(async_client: AsyncClient):
    token = await _register(async_client, "track503@t.com", "track503")
    with patch(
        "backend.application.spotify.use_cases.SpotifyUseCases.get_track",
        new_callable=AsyncMock,
        side_effect=RuntimeError("unexpected"),
    ):
        resp = await async_client.get("/v1/tracks/err", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 503
