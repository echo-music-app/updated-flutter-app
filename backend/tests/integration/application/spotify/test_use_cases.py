"""Tests for application/spotify/use_cases.py — SpotifyUseCases."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from backend.infrastructure.spotify.client import encrypt_token


@pytest.fixture(autouse=True)
def _set_encryption_key(monkeypatch):
    test_key = "a" * 64
    monkeypatch.setenv("SPOTIFY_TOKEN_ENCRYPTION_KEY", test_key)
    from backend.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


def _make_use_cases(db_session):
    from backend.application.spotify.use_cases import SpotifyUseCases
    from backend.core.config import get_settings
    from backend.infrastructure.persistence.repositories.spotify_credentials_repository import (
        SqlAlchemySpotifyCredentialsRepository,
    )
    from backend.infrastructure.persistence.repositories.token_repository import SqlAlchemyTokenRepository
    from backend.infrastructure.spotify.client import SpotifyClient

    return SpotifyUseCases(
        creds_repo=SqlAlchemySpotifyCredentialsRepository(db_session),
        token_repo=SqlAlchemyTokenRepository(db_session),
        spotify_client=SpotifyClient(),
        settings=get_settings(),
    )


# ---------------------------------------------------------------------------
# SpotifyApiError
# ---------------------------------------------------------------------------


class TestSpotifyApiError:
    def test_init_sets_fields(self):
        from backend.domain.spotify.exceptions import SpotifyApiError

        err = SpotifyApiError(404, "not found")
        assert err.status_code == 404
        assert err.detail == "not found"
        assert str(err) == "not found"

    def test_default_detail_is_empty(self):
        from backend.domain.spotify.exceptions import SpotifyApiError

        err = SpotifyApiError(503)
        assert err.status_code == 503
        assert err.detail == ""


# ---------------------------------------------------------------------------
# exchange_code
# ---------------------------------------------------------------------------


class TestExchangeCode:
    @pytest.mark.asyncio
    async def test_happy_path(self, db_session, settings):
        import uuid6

        from backend.core.security import hash_password
        from backend.infrastructure.persistence.models.user import User, UserStatus

        user = User(
            id=uuid6.uuid7(),
            email="exchange_happy@example.com",
            username="exchangehappy",
            password_hash=hash_password("password123"),
            status=UserStatus.active,
        )
        db_session.add(user)
        await db_session.flush()

        mock_token_resp = MagicMock(status_code=200)
        mock_token_resp.json.return_value = {
            "access_token": "spotify_access",
            "refresh_token": "spotify_refresh",
            "expires_in": 3600,
            "scope": "user-read-private streaming",
        }
        mock_user_resp = MagicMock(status_code=200)
        mock_user_resp.json.return_value = {"id": "spotify_user_123"}
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_token_resp
        mock_client.get.return_value = mock_user_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            result = await _make_use_cases(db_session).exchange_code(
                user_id=user.id,
                code="test_code",
                code_verifier="test_verifier",
                redirect_uri="https://example.com/callback",
            )

        assert result.access_token
        assert result.refresh_token
        assert result.expires_in > 0

    @pytest.mark.asyncio
    async def test_spotify_error_raises(self, db_session, settings):
        from backend.domain.spotify.exceptions import SpotifyAuthError

        mock_response = MagicMock(status_code=400)
        mock_response.json.return_value = {"error": "invalid_grant"}
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_response

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyAuthError):
                await _make_use_cases(db_session).exchange_code(
                    user_id=None,
                    code="bad_code",
                    code_verifier="test_verifier",
                    redirect_uri="https://example.com/callback",
                )

    @pytest.mark.asyncio
    async def test_user_profile_fetch_fails(self, db_session, settings):
        from backend.domain.spotify.exceptions import SpotifyAuthError

        mock_token_resp = MagicMock(status_code=200)
        mock_token_resp.json.return_value = {"access_token": "at", "refresh_token": "rt", "expires_in": 3600}
        mock_user_resp = MagicMock(status_code=403)
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_token_resp
        mock_client.get.return_value = mock_user_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyAuthError, match="Failed to fetch Spotify user profile"):
                await _make_use_cases(db_session).exchange_code(user_id=None, code="c", code_verifier="v", redirect_uri="https://x.com")

    @pytest.mark.asyncio
    async def test_no_user_id_no_existing_cred_raises(self, db_session, settings):
        from backend.domain.spotify.exceptions import SpotifyAuthError

        mock_token_resp = MagicMock(status_code=200)
        mock_token_resp.json.return_value = {"access_token": "at", "refresh_token": "rt", "expires_in": 3600}
        mock_user_resp = MagicMock(status_code=200)
        mock_user_resp.json.return_value = {"id": "brand_new_spotify_user"}
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_token_resp
        mock_client.get.return_value = mock_user_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyAuthError, match="user_id required"):
                await _make_use_cases(db_session).exchange_code(user_id=None, code="c", code_verifier="v", redirect_uri="https://x.com")

    @pytest.mark.asyncio
    async def test_upserts_existing_credential(self, db_session, settings):
        from datetime import UTC, datetime, timedelta

        import uuid6

        from backend.core.security import hash_password
        from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
        from backend.infrastructure.persistence.models.user import User, UserStatus

        user = User(
            id=uuid6.uuid7(),
            email="upsert_ec@example.com",
            username="upsertec",
            password_hash=hash_password("pw"),
            status=UserStatus.active,
        )
        db_session.add(user)
        await db_session.flush()

        now = datetime.now(UTC)
        existing = SpotifyCredentials(
            id=uuid6.uuid7(),
            user_id=user.id,
            access_token=encrypt_token("old_at"),
            refresh_token=encrypt_token("old_rt"),
            token_expiry=now + timedelta(hours=1),
            spotify_user_id="returning_spotify_user",
            scope="streaming",
        )
        db_session.add(existing)
        await db_session.flush()

        mock_token_resp = MagicMock(status_code=200)
        mock_token_resp.json.return_value = {
            "access_token": "new_at",
            "refresh_token": "new_rt",
            "expires_in": 3600,
            "scope": "streaming",
        }
        mock_user_resp = MagicMock(status_code=200)
        mock_user_resp.json.return_value = {"id": "returning_spotify_user"}
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_token_resp
        mock_client.get.return_value = mock_user_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            result = await _make_use_cases(db_session).exchange_code(
                user_id=user.id, code="c", code_verifier="v", redirect_uri="https://x.com"
            )

        assert result.access_token
        assert result.refresh_token


# ---------------------------------------------------------------------------
# refresh_token
# ---------------------------------------------------------------------------


class TestRefreshToken:
    @pytest.mark.asyncio
    async def test_refresh_within_60s_window(self, db_session, settings):
        """Proactively refreshes Spotify token when within 60s of expiry."""
        from datetime import UTC, datetime, timedelta

        import uuid6

        from backend.core.security import generate_token, hash_password
        from backend.infrastructure.persistence.models.auth import AccessToken, RefreshToken
        from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
        from backend.infrastructure.persistence.models.user import User, UserStatus

        user = User(
            id=uuid6.uuid7(),
            email="refresh_window@example.com",
            username="refreshwindow",
            password_hash=hash_password("password123"),
            status=UserStatus.active,
        )
        db_session.add(user)
        await db_session.flush()

        now = datetime.now(UTC)
        cred = SpotifyCredentials(
            id=uuid6.uuid7(),
            user_id=user.id,
            access_token=encrypt_token("old_spotify_access"),
            refresh_token=encrypt_token("old_spotify_refresh"),
            token_expiry=now + timedelta(seconds=30),
            spotify_user_id="spotify_proactive_refresh_user",
            scope="streaming",
        )
        db_session.add(cred)

        access_raw, access_hash = generate_token()
        db_session.add(AccessToken(id=uuid6.uuid7(), token_hash=access_hash, user_id=user.id, expires_at=now + timedelta(seconds=900)))

        refresh_raw, refresh_hash = generate_token()
        access_tok_id = (
            (
                await db_session.execute(
                    __import__("sqlalchemy", fromlist=["select"]).select(AccessToken).where(AccessToken.token_hash == access_hash)
                )
            )
            .scalar_one()
            .id
        )
        db_session.add(
            RefreshToken(
                id=uuid6.uuid7(),
                token_hash=refresh_hash,
                user_id=user.id,
                access_token_id=access_tok_id,
                expires_at=now + timedelta(days=30),
            )
        )
        await db_session.flush()

        mock_spotify_resp = MagicMock(status_code=200)
        mock_spotify_resp.json.return_value = {"access_token": "new_spotify_access", "expires_in": 3600}
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_spotify_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            result = await _make_use_cases(db_session).refresh_token(refresh_raw)

        assert result.access_token
        assert result.refresh_token
        assert result.expires_in > 0
        mock_client.post.assert_called_once()

    @pytest.mark.asyncio
    async def test_refresh_handles_spotify_401(self, db_session, settings):
        """Deletes credentials and raises when Spotify returns 401."""
        from datetime import UTC, datetime, timedelta

        import uuid6
        from sqlalchemy import select

        from backend.core.security import generate_token, hash_password
        from backend.domain.spotify.exceptions import SpotifyAuthError
        from backend.infrastructure.persistence.models.auth import AccessToken, RefreshToken
        from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
        from backend.infrastructure.persistence.models.user import User, UserStatus

        user = User(
            id=uuid6.uuid7(),
            email="revoked_spotify@example.com",
            username="revokedspotify",
            password_hash=hash_password("password123"),
            status=UserStatus.active,
        )
        db_session.add(user)
        await db_session.flush()

        now = datetime.now(UTC)
        cred = SpotifyCredentials(
            id=uuid6.uuid7(),
            user_id=user.id,
            access_token=encrypt_token("old_spotify_access"),
            refresh_token=encrypt_token("revoked_spotify_refresh"),
            token_expiry=now + timedelta(seconds=30),
            spotify_user_id="spotify_revoked_user",
            scope="streaming",
        )
        db_session.add(cred)
        cred_id = cred.id

        access_raw, access_hash = generate_token()
        access_tok = AccessToken(id=uuid6.uuid7(), token_hash=access_hash, user_id=user.id, expires_at=now + timedelta(seconds=900))
        db_session.add(access_tok)

        refresh_raw, refresh_hash = generate_token()
        db_session.add(
            RefreshToken(
                id=uuid6.uuid7(),
                token_hash=refresh_hash,
                user_id=user.id,
                access_token_id=access_tok.id,
                expires_at=now + timedelta(days=30),
            )
        )
        await db_session.flush()

        mock_401_resp = MagicMock(status_code=401)
        mock_client = AsyncMock()
        mock_client.post.return_value = mock_401_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyAuthError):
                await _make_use_cases(db_session).refresh_token(refresh_raw)

        result = await db_session.execute(select(SpotifyCredentials).where(SpotifyCredentials.id == cred_id))
        assert result.scalar_one_or_none() is None


# ---------------------------------------------------------------------------
# get_track
# ---------------------------------------------------------------------------


class TestGetTrack:
    @pytest.fixture
    async def user_with_cred(self, db_session):
        from datetime import UTC, datetime, timedelta

        import uuid6

        from backend.core.security import hash_password
        from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
        from backend.infrastructure.persistence.models.user import User, UserStatus

        user = User(
            id=uuid6.uuid7(),
            email="gettrack@example.com",
            username="gettrackuser",
            password_hash=hash_password("pw"),
            status=UserStatus.active,
        )
        db_session.add(user)
        await db_session.flush()

        now = datetime.now(UTC)
        cred = SpotifyCredentials(
            id=uuid6.uuid7(),
            user_id=user.id,
            access_token=encrypt_token("spotify_at"),
            refresh_token=encrypt_token("spotify_rt"),
            token_expiry=now + timedelta(hours=1),
            spotify_user_id="get_track_spotify_user",
            scope="streaming",
        )
        db_session.add(cred)
        await db_session.flush()
        return user

    @pytest.mark.asyncio
    async def test_no_credentials_raises_401(self, db_session, settings):
        import uuid6

        from backend.domain.spotify.exceptions import SpotifyApiError

        with pytest.raises(SpotifyApiError) as exc_info:
            await _make_use_cases(db_session).get_track(uuid6.uuid7(), "track_id")
        assert exc_info.value.status_code == 401

    @pytest.mark.asyncio
    async def test_success_with_artists_and_images(self, db_session, settings, user_with_cred):
        mock_resp = MagicMock(status_code=200)
        mock_resp.json.return_value = {
            "id": "abc",
            "uri": "spotify:track:abc",
            "name": "Test Track",
            "artists": [{"name": "Artist One"}],
            "album": {"images": [{"url": "https://i.example.com/art.jpg"}]},
            "duration_ms": 180000,
        }
        mock_client = AsyncMock()
        mock_client.get.return_value = mock_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            track = await _make_use_cases(db_session).get_track(user_with_cred.id, "abc")

        assert track.id == "abc"
        assert track.artist_name == "Artist One"
        assert track.album_art_url == "https://i.example.com/art.jpg"

    @pytest.mark.asyncio
    async def test_success_no_artists_no_images(self, db_session, settings, user_with_cred):
        mock_resp = MagicMock(status_code=200)
        mock_resp.json.return_value = {
            "id": "xyz",
            "uri": "spotify:track:xyz",
            "name": "Unknown",
            "artists": [],
            "album": {},
            "duration_ms": 0,
        }
        mock_client = AsyncMock()
        mock_client.get.return_value = mock_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            track = await _make_use_cases(db_session).get_track(user_with_cred.id, "xyz")

        assert track.artist_name == "Unknown Artist"
        assert track.album_art_url == ""

    @pytest.mark.parametrize(
        "status_code, expected",
        [(401, 401), (404, 404), (429, 503), (500, 503)],
    )
    @pytest.mark.asyncio
    async def test_http_errors_map_to_api_error(self, db_session, settings, user_with_cred, status_code, expected):
        from backend.domain.spotify.exceptions import SpotifyApiError

        mock_resp = MagicMock(status_code=status_code)
        mock_client = AsyncMock()
        mock_client.get.return_value = mock_resp

        with patch("backend.infrastructure.spotify.client.httpx.AsyncClient") as MockClient:
            MockClient.return_value.__aenter__ = AsyncMock(return_value=mock_client)
            MockClient.return_value.__aexit__ = AsyncMock(return_value=False)
            with pytest.raises(SpotifyApiError) as exc_info:
                await _make_use_cases(db_session).get_track(user_with_cred.id, "abc")
        assert exc_info.value.status_code == expected
