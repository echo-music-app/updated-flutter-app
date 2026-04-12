"""Integration tests for infrastructure/spotify/client.py — SpotifyClient (requires DB)."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock, patch

import pytest
import uuid6

from backend.core.security import hash_password
from backend.domain.spotify.exceptions import SpotifyAuthError
from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
from backend.infrastructure.persistence.models.user import User, UserStatus
from backend.infrastructure.spotify.client import SpotifyClient, encrypt_token


@pytest.fixture(autouse=True)
def _set_encryption_key(monkeypatch):
    test_key = "ab" * 32  # 64 hex chars = 32 bytes
    monkeypatch.setenv("SPOTIFY_TOKEN_ENCRYPTION_KEY", test_key)
    from backend.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture
async def cred(db_session):
    user = User(
        id=uuid6.uuid7(),
        email="refreshspot@example.com",
        username="refreshspot",
        password_hash=hash_password("pw"),
        status=UserStatus.active,
    )
    db_session.add(user)
    await db_session.flush()

    now = datetime.now(UTC)
    c = SpotifyCredentials(
        id=uuid6.uuid7(),
        user_id=user.id,
        access_token=encrypt_token("old_at"),
        refresh_token=encrypt_token("old_rt"),
        token_expiry=now + timedelta(hours=1),
        spotify_user_id="refresh_spotify_token_user",
        scope="streaming",
    )
    db_session.add(c)
    await db_session.flush()
    return c


class TestSpotifyClientRefreshToken:
    @pytest.mark.anyio
    async def test_non_200_non_401_raises_auth_error(self, db_session, settings, cred):
        mock_resp = MagicMock(status_code=500)
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_resp

        client = SpotifyClient()
        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyAuthError, match="Spotify token refresh failed"):
                await client.refresh_token(cred.refresh_token)

    @pytest.mark.anyio
    async def test_returns_new_tokens_when_provided(self, db_session, settings, cred):
        mock_resp = MagicMock(status_code=200)
        mock_resp.json.return_value = {
            "access_token": "refreshed_at",
            "refresh_token": "brand_new_rt",
            "expires_in": 3600,
        }
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_resp

        client = SpotifyClient()
        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            data = await client.refresh_token(cred.refresh_token)

        assert data["access_token"] == "refreshed_at"
        assert data["refresh_token"] == "brand_new_rt"
