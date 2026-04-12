"""Contract tests for POST /v1/search/music."""

from unittest.mock import AsyncMock, patch

import pytest
from httpx import AsyncClient

from backend.domain.music_search.entities import (
    ResultAttribution,
    SearchResponseSummary,
    UnifiedMusicSearchResponse,
    UnifiedResultItem,
)
from backend.domain.music_search.exceptions import AllProvidersUnavailableError


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


def _make_full_response(query: str = "test") -> UnifiedMusicSearchResponse:
    item = UnifiedResultItem(
        id="abc123",
        type="track",
        display_name="Test Track",
        primary_creator_name="Test Artist",
        duration_ms=180000,
        playable_link="https://open.spotify.com/track/abc",
        artwork_url=None,
        sources=[ResultAttribution(source="spotify", source_item_id="spotify:track:abc")],
        relevance_score=0.9,
    )
    return UnifiedMusicSearchResponse(
        query=query,
        limit=20,
        tracks=[item],
        albums=[],
        artists=[],
        summary=SearchResponseSummary(
            total_count=1,
            per_type_counts={"tracks": 1, "albums": 0, "artists": 0},
            per_source_counts={"spotify": 1, "soundcloud": 0},
            source_statuses={"spotify": "matched", "soundcloud": "no_matches"},
            is_partial=False,
            warnings=[],
        ),
    )


def _make_empty_response(query: str = "noresult") -> UnifiedMusicSearchResponse:
    return UnifiedMusicSearchResponse(
        query=query,
        limit=20,
        tracks=[],
        albums=[],
        artists=[],
        summary=SearchResponseSummary(
            total_count=0,
            per_type_counts={"tracks": 0, "albums": 0, "artists": 0},
            per_source_counts={"spotify": 0, "soundcloud": 0},
            source_statuses={"spotify": "no_matches", "soundcloud": "no_matches"},
            is_partial=False,
            warnings=[],
        ),
    )


def _make_partial_response(query: str = "partial") -> UnifiedMusicSearchResponse:
    item = UnifiedResultItem(
        id="x1",
        type="track",
        display_name="Partial Track",
        sources=[ResultAttribution(source="spotify", source_item_id="sp:1")],
        relevance_score=0.5,
    )
    return UnifiedMusicSearchResponse(
        query=query,
        limit=20,
        tracks=[item],
        albums=[],
        artists=[],
        summary=SearchResponseSummary(
            total_count=1,
            per_type_counts={"tracks": 1, "albums": 0, "artists": 0},
            per_source_counts={"spotify": 1, "soundcloud": 0},
            source_statuses={"spotify": "matched", "soundcloud": "unavailable"},
            is_partial=True,
            warnings=["soundcloud timed out"],
        ),
    )


# ---------- Authentication ----------


@pytest.mark.anyio
async def test_music_search_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post("/v1/search/music", json={"q": "test"})
    assert response.status_code == 401


# ---------- Request validation ----------


@pytest.mark.anyio
async def test_music_search_rejects_empty_query(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_1@example.com", "music_contract_1")
    response = await async_client.post(
        "/v1/search/music",
        json={"q": ""},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_music_search_rejects_whitespace_only_query(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_2@example.com", "music_contract_2")
    response = await async_client.post(
        "/v1/search/music",
        json={"q": "   "},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_music_search_rejects_limit_below_min(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_3@example.com", "music_contract_3")
    response = await async_client.post(
        "/v1/search/music",
        json={"q": "test", "limit": 0},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_music_search_rejects_limit_above_max(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_4@example.com", "music_contract_4")
    response = await async_client.post(
        "/v1/search/music",
        json={"q": "test", "limit": 51},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


# ---------- Success responses ----------


@pytest.mark.anyio
async def test_music_search_success_response_shape(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_5@example.com", "music_contract_5")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_full_response("test"),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    body = response.json()
    assert "tracks" in body
    assert "albums" in body
    assert "artists" in body
    assert "summary" in body
    assert isinstance(body["tracks"], list)
    assert isinstance(body["albums"], list)
    assert isinstance(body["artists"], list)


@pytest.mark.anyio
async def test_music_search_no_match_returns_empty_arrays(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_6@example.com", "music_contract_6")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_empty_response(),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "noresult"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    body = response.json()
    assert body["tracks"] == []
    assert body["albums"] == []
    assert body["artists"] == []
    assert body["summary"]["total_count"] == 0


@pytest.mark.anyio
async def test_music_search_partial_response_shape(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_7@example.com", "music_contract_7")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_partial_response(),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "partial"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200
    body = response.json()
    assert body["summary"]["is_partial"] is True
    assert body["summary"]["source_statuses"]["soundcloud"] == "unavailable"
    assert len(body["summary"]["warnings"]) > 0


@pytest.mark.anyio
async def test_music_search_both_unavailable_returns_503(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_8@example.com", "music_contract_8")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        side_effect=AllProvidersUnavailableError({"spotify": "down", "soundcloud": "down"}),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 503


@pytest.mark.anyio
async def test_music_search_accepts_punctuation_and_non_latin(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_9@example.com", "music_contract_9")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_empty_response("AC/DC"),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "AC/DC"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200

    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_empty_response("はっぴいえんど"),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "はっぴいえんど"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 200


# ---------- Result item shape ----------


@pytest.mark.anyio
async def test_music_search_item_has_required_fields(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_10@example.com", "music_contract_10")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_full_response(),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    track = response.json()["tracks"][0]
    required_fields = {"id", "type", "display_name", "sources", "relevance_score"}
    for field in required_fields:
        assert field in track, f"Missing field: {field}"
    assert len(track["sources"]) >= 1
    source = track["sources"][0]
    assert "source" in source
    assert "source_item_id" in source


# ---------- Source attribution shape ----------


@pytest.mark.anyio
async def test_music_search_summary_has_source_statuses(async_client: AsyncClient):
    token = await _register(async_client, "music_contract_11@example.com", "music_contract_11")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        return_value=_make_full_response(),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    summary = response.json()["summary"]
    assert "source_statuses" in summary
    assert "spotify" in summary["source_statuses"]
    assert "soundcloud" in summary["source_statuses"]
    assert summary["source_statuses"]["spotify"] in ("matched", "no_matches", "unavailable")
    assert summary["source_statuses"]["soundcloud"] in ("matched", "no_matches", "unavailable")


# ---------- Domain-level SearchValidationError maps to 422 ----------


@pytest.mark.anyio
async def test_music_search_domain_validation_error_returns_422(async_client: AsyncClient):
    """If the use case raises SearchValidationError, the endpoint returns 422."""
    from backend.domain.music_search.exceptions import SearchValidationError

    token = await _register(async_client, "music_contract_12@example.com", "music_contract_12")
    with patch(
        "backend.presentation.api.v1.music_search.MusicSearchUseCase.search",
        new_callable=AsyncMock,
        side_effect=SearchValidationError("bad query"),
    ):
        response = await async_client.post(
            "/v1/search/music",
            json={"q": "test"},
            headers={"Authorization": f"Bearer {token}"},
        )
    assert response.status_code == 422
