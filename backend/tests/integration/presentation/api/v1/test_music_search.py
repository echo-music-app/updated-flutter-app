"""Integration tests for POST /v1/search/music."""

from contextlib import contextmanager
from unittest.mock import MagicMock

import pytest
from fastapi import FastAPI
from httpx import AsyncClient

from backend.domain.music_search.entities import SourceResultItem
from backend.domain.music_search.exceptions import ProviderRateLimitError, ProviderUnavailableError
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


def _sp_track(track_id: str, name: str, creator: str, duration_ms: int = 180000) -> SourceResultItem:
    return SourceResultItem(
        source="spotify",
        source_item_id=f"spotify:track:{track_id}",
        type="track",
        display_name=name,
        primary_creator_name=creator,
        duration_ms=duration_ms,
        playable_link=f"https://open.spotify.com/track/{track_id}",
        artwork_url=None,
        provider_relevance=0.9,
    )


def _sc_track(track_id: str, name: str, creator: str, duration_ms: int = 185000) -> SourceResultItem:
    return SourceResultItem(
        source="soundcloud",
        source_item_id=f"soundcloud:tracks:{track_id}",
        type="track",
        display_name=name,
        primary_creator_name=creator,
        duration_ms=duration_ms,
        playable_link=f"https://soundcloud.com/{track_id}",
        artwork_url=None,
        provider_relevance=None,
    )


class _MockProvider:
    def __init__(self, tracks=None, albums=None, artists=None, raise_exc=None):
        self._tracks = tracks or []
        self._albums = albums or []
        self._artists = artists or []
        self._raise_exc = raise_exc

    async def search_tracks(self, term, limit):
        if self._raise_exc:
            raise self._raise_exc
        return self._tracks

    async def search_albums(self, term, limit):
        if self._raise_exc:
            raise self._raise_exc
        return self._albums

    async def search_artists(self, term, limit):
        if self._raise_exc:
            raise self._raise_exc
        return self._artists


def _make_use_case(spotify_provider, sc_provider):
    from backend.application.music_search.use_cases import MusicSearchUseCase

    mock_settings = MagicMock()
    mock_settings.music_search_request_timeout_seconds = 5.0
    mock_settings.music_search_provider_bulkhead_limit = 10
    return MusicSearchUseCase(
        spotify_client=spotify_provider,
        soundcloud_client=sc_provider,
        settings=mock_settings,
    )


@contextmanager
def _override_use_case(app: FastAPI, spotify_provider, sc_provider):
    use_case = _make_use_case(spotify_provider, sc_provider)
    app.dependency_overrides[get_music_search_use_case] = lambda: use_case
    try:
        yield
    finally:
        app.dependency_overrides.pop(get_music_search_use_case, None)


# ---------- Full success ----------


@pytest.mark.anyio
async def test_music_search_merged_spotify_and_soundcloud(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_1@example.com", "music_int_1")

    sp_track = _sp_track("abc", "Daft Punk Song", "Daft Punk", duration_ms=224000)
    sc_track = _sc_track("sc1", "Different Song", "Other Artist", duration_ms=300000)

    with _override_use_case(app, _MockProvider(tracks=[sp_track]), _MockProvider(tracks=[sc_track])):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "daft punk"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    body = response.json()
    assert len(body["tracks"]) == 2
    assert body["summary"]["is_partial"] is False
    assert body["summary"]["source_statuses"]["spotify"] == "matched"
    assert body["summary"]["source_statuses"]["soundcloud"] == "matched"


@pytest.mark.anyio
async def test_music_search_deduplicates_cross_source_tracks(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_2@example.com", "music_int_2")

    # Same track on both providers (same title/creator, same duration bucket)
    sp_track = _sp_track("sp1", "Harder Better Faster", "Daft Punk", duration_ms=224000)
    sc_track = _sc_track("sc1", "harder better faster", "daft punk", duration_ms=224500)

    with _override_use_case(app, _MockProvider(tracks=[sp_track]), _MockProvider(tracks=[sc_track])):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "daft punk"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    body = response.json()
    # Should be deduplicated to 1 item with 2 sources
    assert len(body["tracks"]) == 1
    assert len(body["tracks"][0]["sources"]) == 2


@pytest.mark.anyio
async def test_music_search_non_latin_and_punctuation_query(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_3@example.com", "music_int_3")

    with _override_use_case(app, _MockProvider(), _MockProvider()):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "はっぴいえんど"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200

    with _override_use_case(app, _MockProvider(), _MockProvider()):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "AC/DC"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200


# ---------- Partial response ----------


@pytest.mark.anyio
async def test_music_search_partial_when_soundcloud_timeout(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_4@example.com", "music_int_4")

    sp_track = _sp_track("sp1", "Spotify Song", "Artist")
    sc_error = ProviderUnavailableError("soundcloud", "timeout")

    with _override_use_case(app, _MockProvider(tracks=[sp_track]), _MockProvider(raise_exc=sc_error)):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["summary"]["is_partial"] is True
    assert body["summary"]["source_statuses"]["soundcloud"] == "unavailable"
    assert body["summary"]["source_statuses"]["spotify"] == "matched"
    assert len(body["tracks"]) == 1


@pytest.mark.anyio
async def test_music_search_partial_when_spotify_throttled(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_5@example.com", "music_int_5")

    sc_track = _sc_track("sc1", "SoundCloud Song", "Artist")
    sp_error = ProviderRateLimitError("spotify", "429")

    with _override_use_case(app, _MockProvider(raise_exc=sp_error), _MockProvider(tracks=[sc_track])):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["summary"]["is_partial"] is True
    assert body["summary"]["source_statuses"]["spotify"] == "unavailable"


# ---------- Both unavailable ----------


@pytest.mark.anyio
async def test_music_search_503_when_both_unavailable(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_6@example.com", "music_int_6")

    err = ProviderUnavailableError("provider", "down")
    with _override_use_case(app, _MockProvider(raise_exc=err), _MockProvider(raise_exc=err)):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert response.status_code == 503


# ---------- Deterministic ordering ----------


@pytest.mark.anyio
async def test_music_search_deterministic_ordering(async_client: AsyncClient, app: FastAPI):
    token = await _register(async_client, "music_int_7@example.com", "music_int_7")

    tracks = [_sp_track(f"t{i}", f"Track {i}", "Artist", duration_ms=i * 10000) for i in range(1, 6)]

    # Call twice and compare ordering
    with _override_use_case(app, _MockProvider(tracks=tracks), _MockProvider()):
        r1 = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    with _override_use_case(app, _MockProvider(tracks=tracks), _MockProvider()):
        r2 = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )

    assert [t["id"] for t in r1.json()["tracks"]] == [t["id"] for t in r2.json()["tracks"]]
