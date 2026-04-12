"""Unit tests for music provider client adapters."""

from unittest.mock import AsyncMock, MagicMock, patch

import pytest

from backend.domain.music_search.exceptions import ProviderAuthError, ProviderRateLimitError, ProviderUnavailableError
from backend.infrastructure.music_providers.soundcloud_search_client import SoundCloudSearchClient
from backend.infrastructure.music_providers.spotify_search_client import SpotifySearchClient


class MockSettings:
    spotify_client_id = "client_id"
    spotify_client_secret = MagicMock(get_secret_value=lambda: "client_secret")
    spotify_token_url = "https://accounts.spotify.com/api/token"
    spotify_search_default_market = "US"
    soundcloud_client_id = "sc_id"
    soundcloud_client_secret = MagicMock(get_secret_value=lambda: "sc_secret")
    soundcloud_token_url = "https://api.soundcloud.com/oauth2/token"
    music_search_request_timeout_seconds = 5.0


def _make_response(status_code: int, json_body: dict) -> MagicMock:
    resp = MagicMock()
    resp.status_code = status_code
    resp.json.return_value = json_body
    return resp


def _make_http_mock(post_resp=None, get_resp=None) -> AsyncMock:
    mock_http = AsyncMock()
    mock_http.__aenter__ = AsyncMock(return_value=mock_http)
    mock_http.__aexit__ = AsyncMock(return_value=False)
    if post_resp is not None:
        mock_http.post = AsyncMock(return_value=post_resp)
    if get_resp is not None:
        mock_http.get = AsyncMock(return_value=get_resp)
    return mock_http


# ---------- SpotifySearchClient — token acquisition ----------


@pytest.mark.anyio
async def test_spotify_is_token_valid_false_when_no_token():
    client = SpotifySearchClient(MockSettings())
    assert client._is_token_valid() is False


@pytest.mark.anyio
async def test_spotify_is_token_valid_true_when_fresh():
    import time

    client = SpotifySearchClient(MockSettings())
    client._token = "tok"
    client._token_expires_at = time.monotonic() + 100
    assert client._is_token_valid() is True


@pytest.mark.anyio
async def test_spotify_acquire_token_success():
    client = SpotifySearchClient(MockSettings())
    token_resp = _make_response(200, {"access_token": "new_tok", "expires_in": 3600})
    mock_http = _make_http_mock(post_resp=token_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        token = await client._acquire_token()

    assert token == "new_tok"
    assert client._token == "new_tok"


@pytest.mark.anyio
async def test_spotify_acquire_token_uses_cache():
    import time

    client = SpotifySearchClient(MockSettings())
    client._token = "cached"
    client._token_expires_at = time.monotonic() + 100

    token = await client._acquire_token()
    assert token == "cached"


@pytest.mark.anyio
async def test_spotify_token_request_401_raises_auth_error():
    client = SpotifySearchClient(MockSettings())
    token_resp = _make_response(401, {})
    mock_http = _make_http_mock(post_resp=token_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client._acquire_token()


@pytest.mark.anyio
async def test_spotify_token_request_403_raises_auth_error():
    client = SpotifySearchClient(MockSettings())
    token_resp = _make_response(403, {})
    mock_http = _make_http_mock(post_resp=token_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client._acquire_token()


@pytest.mark.anyio
async def test_spotify_token_request_500_raises_unavailable_error():
    client = SpotifySearchClient(MockSettings())
    token_resp = _make_response(500, {})
    mock_http = _make_http_mock(post_resp=token_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client._acquire_token()


# ---------- SpotifySearchClient — search error paths ----------


@pytest.mark.anyio
async def test_spotify_search_tracks_maps_items():
    settings = MockSettings()
    client = SpotifySearchClient(settings)

    token_resp = _make_response(200, {"access_token": "tok", "expires_in": 3600})
    track_raw = {
        "id": "abc",
        "name": "Song",
        "artists": [{"name": "Artist"}],
        "duration_ms": 180000,
        "external_urls": {"spotify": "https://open.spotify.com/track/abc"},
        "album": {"images": [{"url": "https://img/art.jpg"}]},
        "popularity": 80,
    }
    search_resp = _make_response(200, {"tracks": {"items": [track_raw]}})
    mock_http = _make_http_mock(post_resp=token_resp, get_resp=search_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_tracks("Song", 10)

    assert len(results) == 1
    item = results[0]
    assert item.source == "spotify"
    assert item.type == "track"
    assert item.display_name == "Song"
    assert item.primary_creator_name == "Artist"
    assert item.duration_ms == 180000
    assert item.provider_relevance == pytest.approx(0.8)


@pytest.mark.anyio
async def test_spotify_search_returns_401_raises_auth_error():
    client = SpotifySearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(401, {}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client.search_tracks("test", 10)

    # Token invalidated after 401
    assert client._token is None


@pytest.mark.anyio
async def test_spotify_search_returns_403_raises_auth_error():
    client = SpotifySearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(403, {}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client.search_tracks("test", 10)


@pytest.mark.anyio
async def test_spotify_search_returns_429_raises_rate_limit_error():
    client = SpotifySearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(429, {}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderRateLimitError):
            await client.search_tracks("test", 10)


@pytest.mark.anyio
async def test_spotify_search_returns_503_raises_unavailable_error():
    client = SpotifySearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(503, {}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client.search_tracks("test", 10)


@pytest.mark.anyio
async def test_spotify_search_returns_unexpected_status_raises_unavailable():
    client = SpotifySearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(418, {}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client.search_tracks("test", 10)


# ---------- SpotifySearchClient — albums and artists ----------


@pytest.mark.anyio
async def test_spotify_search_albums_maps_items():
    client = SpotifySearchClient(MockSettings())
    client._token = "tok"
    client._token_expires_at = float("inf")

    album_raw = {
        "id": "alb1",
        "name": "Great Album",
        "artists": [{"name": "Band"}],
        "images": [{"url": "https://img/album.jpg"}],
        "external_urls": {"spotify": "https://open.spotify.com/album/alb1"},
        "popularity": 70,
    }
    mock_http = _make_http_mock(get_resp=_make_response(200, {"albums": {"items": [album_raw]}}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_albums("Great Album", 10)

    assert len(results) == 1
    item = results[0]
    assert item.type == "album"
    assert item.display_name == "Great Album"
    assert item.primary_creator_name == "Band"
    assert item.source_item_id == "spotify:album:alb1"
    assert item.duration_ms is None


@pytest.mark.anyio
async def test_spotify_search_artists_maps_items():
    client = SpotifySearchClient(MockSettings())
    client._token = "tok"
    client._token_expires_at = float("inf")

    artist_raw = {
        "id": "art1",
        "name": "Famous Artist",
        "images": [{"url": "https://img/artist.jpg"}],
        "external_urls": {"spotify": "https://open.spotify.com/artist/art1"},
        "popularity": 90,
    }
    mock_http = _make_http_mock(get_resp=_make_response(200, {"artists": {"items": [artist_raw]}}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_artists("Famous Artist", 10)

    assert len(results) == 1
    item = results[0]
    assert item.type == "artist"
    assert item.display_name == "Famous Artist"
    assert item.primary_creator_name is None
    assert item.source_item_id == "spotify:artist:art1"


@pytest.mark.anyio
async def test_spotify_map_track_no_artists():
    """Tracks with no artists list map creator to None."""
    raw = {
        "id": "t1",
        "name": "Instrumental",
        "artists": [],
        "duration_ms": 120000,
        "external_urls": {},
        "album": {"images": []},
        "popularity": 50,
    }
    item = SpotifySearchClient._map_track(raw)
    assert item.primary_creator_name is None
    assert item.artwork_url is None


@pytest.mark.anyio
async def test_spotify_map_album_no_images():
    raw = {
        "id": "a1",
        "name": "Album",
        "artists": [],
        "images": [],
        "external_urls": {},
        "popularity": 0,
    }
    item = SpotifySearchClient._map_album(raw)
    assert item.artwork_url is None
    assert item.primary_creator_name is None


@pytest.mark.anyio
async def test_spotify_map_artist_no_images():
    raw = {
        "id": "ar1",
        "name": "Artist",
        "images": [],
        "external_urls": {},
        "popularity": 0,
    }
    item = SpotifySearchClient._map_artist(raw)
    assert item.artwork_url is None


@pytest.mark.anyio
async def test_spotify_token_cached_across_calls():
    client = SpotifySearchClient(MockSettings())

    token_resp = _make_response(200, {"access_token": "cached_sp", "expires_in": 3600})
    search_resp = _make_response(200, {"tracks": {"items": []}})
    mock_http = _make_http_mock(post_resp=token_resp, get_resp=search_resp)

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        await client.search_tracks("q", 5)
        await client.search_tracks("q", 5)

    assert mock_http.post.call_count == 1


@pytest.mark.anyio
async def test_spotify_search_no_market_skips_param():
    """When default_market is empty, market param should not be added."""

    class NoMarketSettings(MockSettings):
        spotify_search_default_market = ""

    client = SpotifySearchClient(NoMarketSettings())
    client._token = "tok"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(200, {"tracks": {"items": []}}))

    with patch("backend.infrastructure.music_providers.spotify_search_client.httpx.AsyncClient", return_value=mock_http):
        await client.search_tracks("q", 5)

    call_kwargs = mock_http.get.call_args.kwargs
    assert "market" not in call_kwargs.get("params", {})


# ---------- SoundCloudSearchClient — token acquisition ----------


@pytest.mark.anyio
async def test_soundcloud_is_token_valid_false_when_no_token():
    client = SoundCloudSearchClient(MockSettings())
    assert client._is_token_valid() is False


@pytest.mark.anyio
async def test_soundcloud_is_token_valid_true_when_fresh():
    import time

    client = SoundCloudSearchClient(MockSettings())
    client._token = "sc_tok"
    client._token_expires_at = time.monotonic() + 100
    assert client._is_token_valid() is True


@pytest.mark.anyio
async def test_soundcloud_acquire_token_success():
    client = SoundCloudSearchClient(MockSettings())
    token_resp = _make_response(200, {"access_token": "new_sc_tok", "expires_in": 3600})
    mock_http = _make_http_mock(post_resp=token_resp)

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        token = await client._acquire_token()

    assert token == "new_sc_tok"


@pytest.mark.anyio
async def test_soundcloud_acquire_token_uses_cache():
    import time

    client = SoundCloudSearchClient(MockSettings())
    client._token = "cached_sc"
    client._token_expires_at = time.monotonic() + 100

    token = await client._acquire_token()
    assert token == "cached_sc"


@pytest.mark.anyio
async def test_soundcloud_token_request_401_raises_auth_error():
    client = SoundCloudSearchClient(MockSettings())
    mock_http = _make_http_mock(post_resp=_make_response(401, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client._acquire_token()


@pytest.mark.anyio
async def test_soundcloud_token_request_403_raises_auth_error():
    client = SoundCloudSearchClient(MockSettings())
    mock_http = _make_http_mock(post_resp=_make_response(403, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client._acquire_token()


@pytest.mark.anyio
async def test_soundcloud_token_request_500_raises_unavailable_error():
    client = SoundCloudSearchClient(MockSettings())
    mock_http = _make_http_mock(post_resp=_make_response(500, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client._acquire_token()


# ---------- SoundCloudSearchClient — search error paths ----------


@pytest.mark.anyio
async def test_soundcloud_search_tracks_maps_items():
    client = SoundCloudSearchClient(MockSettings())

    token_resp = _make_response(200, {"access_token": "sc_tok", "expires_in": 3600})
    track_raw = {
        "id": 123,
        "title": "SC Song",
        "user": {"username": "SC Artist"},
        "duration": 200000,
        "permalink_url": "https://soundcloud.com/track/sc-song",
        "artwork_url": None,
    }
    collection_resp = _make_response(200, {"collection": [track_raw]})
    mock_http = _make_http_mock(post_resp=token_resp, get_resp=collection_resp)

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_tracks("SC Song", 10)

    assert len(results) == 1
    item = results[0]
    assert item.source == "soundcloud"
    assert item.type == "track"
    assert item.display_name == "SC Song"
    assert item.primary_creator_name == "SC Artist"
    assert item.duration_ms == 200000


@pytest.mark.anyio
async def test_soundcloud_search_returns_401_raises_auth_error():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(401, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderAuthError):
            await client.search_tracks("test", 10)

    assert client._token is None


@pytest.mark.anyio
async def test_soundcloud_search_returns_429_raises_rate_limit_error():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(429, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderRateLimitError):
            await client.search_tracks("test", 10)


@pytest.mark.anyio
async def test_soundcloud_search_returns_500_raises_unavailable_error():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(500, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client.search_tracks("test", 10)


@pytest.mark.anyio
async def test_soundcloud_search_returns_unexpected_status_raises_unavailable():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "existing"
    client._token_expires_at = float("inf")

    mock_http = _make_http_mock(get_resp=_make_response(418, {}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        with pytest.raises(ProviderUnavailableError):
            await client.search_tracks("test", 10)


# ---------- SoundCloudSearchClient — albums and artists ----------


@pytest.mark.anyio
async def test_soundcloud_search_albums_maps_items():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "tok"
    client._token_expires_at = float("inf")

    playlist_raw = {
        "id": 999,
        "title": "SC Playlist",
        "user": {"username": "SC Creator"},
        "permalink_url": "https://soundcloud.com/playlist/999",
        "artwork_url": "https://img/pl.jpg",
    }
    mock_http = _make_http_mock(get_resp=_make_response(200, {"collection": [playlist_raw]}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_albums("SC Playlist", 10)

    assert len(results) == 1
    item = results[0]
    assert item.type == "album"
    assert item.display_name == "SC Playlist"
    assert item.source_item_id == "soundcloud:playlists:999"
    assert item.primary_creator_name == "SC Creator"
    assert item.artwork_url == "https://img/pl.jpg"


@pytest.mark.anyio
async def test_soundcloud_search_artists_maps_items():
    client = SoundCloudSearchClient(MockSettings())
    client._token = "tok"
    client._token_expires_at = float("inf")

    user_raw = {
        "id": 456,
        "username": "SC User",
        "full_name": "SC Full Name",
        "permalink_url": "https://soundcloud.com/sc-user",
        "avatar_url": "https://img/avatar.jpg",
    }
    mock_http = _make_http_mock(get_resp=_make_response(200, {"collection": [user_raw]}))

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        results = await client.search_artists("SC User", 10)

    assert len(results) == 1
    item = results[0]
    assert item.type == "artist"
    assert item.display_name == "SC User"
    assert item.source_item_id == "soundcloud:users:456"
    assert item.artwork_url == "https://img/avatar.jpg"


@pytest.mark.anyio
async def test_soundcloud_map_artist_falls_back_to_full_name():
    """When username is missing, display_name falls back to full_name."""
    raw = {
        "id": 1,
        "username": None,
        "full_name": "Real Name",
        "permalink_url": None,
        "avatar_url": None,
    }
    item = SoundCloudSearchClient._map_artist(raw)
    assert item.display_name == "Real Name"


@pytest.mark.anyio
async def test_soundcloud_map_artist_empty_display_name_fallback():
    """When both username and full_name are absent, display_name is empty string."""
    raw = {"id": 1, "permalink_url": None, "avatar_url": None}
    item = SoundCloudSearchClient._map_artist(raw)
    assert item.display_name == ""


@pytest.mark.anyio
async def test_soundcloud_token_cached_across_calls():
    client = SoundCloudSearchClient(MockSettings())

    token_resp = _make_response(200, {"access_token": "cached_tok", "expires_in": 3600})
    collection_resp = _make_response(200, {"collection": []})
    mock_http = _make_http_mock(post_resp=token_resp, get_resp=collection_resp)

    with patch("backend.infrastructure.music_providers.soundcloud_search_client.httpx.AsyncClient", return_value=mock_http):
        await client.search_tracks("q", 5)
        await client.search_tracks("q", 5)

    # Token acquired only once (second call uses cache)
    assert mock_http.post.call_count == 1
