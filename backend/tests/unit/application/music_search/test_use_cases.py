"""Unit tests for music search use cases."""

import pytest

from backend.application.music_search.use_cases import (
    MusicSearchUseCase,
    _album_dedup_key,
    _artist_dedup_key,
    _deduplicate,
    _sort_items,
    _track_dedup_key,
    normalize_query,
    validate_limit,
)
from backend.domain.music_search.entities import ResultAttribution, SourceResultItem, UnifiedResultItem
from backend.domain.music_search.exceptions import AllProvidersUnavailableError, SearchValidationError

# ---------- normalize_query ----------


def test_normalize_query_strips_whitespace():
    assert normalize_query("  hello  ") == "hello"


def test_normalize_query_preserves_punctuation():
    assert normalize_query("AC/DC") == "AC/DC"


def test_normalize_query_preserves_non_latin():
    assert normalize_query(" はっぴいえんど ") == "はっぴいえんど"


# ---------- validate_limit ----------


def test_validate_limit_accepts_bounds():
    assert validate_limit(1) == 1
    assert validate_limit(10) == 10
    assert validate_limit(5) == 5


def test_validate_limit_rejects_zero():
    with pytest.raises(ValueError):
        validate_limit(0)


def test_validate_limit_rejects_above_max():
    with pytest.raises(ValueError):
        validate_limit(11)


# ---------- Dedup keys ----------


def _make_item(**kwargs) -> SourceResultItem:
    defaults = dict(
        source="spotify",
        source_item_id="id1",
        type="track",
        display_name="Song",
        primary_creator_name="Artist",
        duration_ms=180000,
        provider_relevance=0.8,
    )
    defaults.update(kwargs)
    return SourceResultItem(**defaults)


def test_track_dedup_key_normalises_case():
    a = _make_item(display_name="Hello", primary_creator_name="World", duration_ms=10000)
    b = _make_item(display_name="hello", primary_creator_name="world", duration_ms=10000)
    assert _track_dedup_key(a) == _track_dedup_key(b)


def test_track_dedup_key_uses_duration_bucket():
    a = _make_item(display_name="Song", primary_creator_name="A", duration_ms=10000)
    b = _make_item(display_name="Song", primary_creator_name="A", duration_ms=30000)
    assert _track_dedup_key(a) != _track_dedup_key(b)


def test_album_dedup_key_ignores_duration():
    a = _make_item(type="album", display_name="Record", primary_creator_name="Band", duration_ms=None)
    b = _make_item(type="album", display_name="Record", primary_creator_name="Band", duration_ms=None)
    assert _album_dedup_key(a) == _album_dedup_key(b)


def test_artist_dedup_key_only_name():
    a = _make_item(type="artist", display_name="DJ Echo", primary_creator_name=None)
    b = _make_item(type="artist", display_name="dj echo", primary_creator_name=None)
    assert _artist_dedup_key(a) == _artist_dedup_key(b)


# ---------- _deduplicate ----------


def test_deduplicate_merges_cross_provider_duplicates():
    spotify_item = _make_item(
        source="spotify",
        source_item_id="sp1",
        display_name="Hello",
        primary_creator_name="World",
        duration_ms=10000,
        provider_relevance=0.9,
    )
    sc_item = _make_item(
        source="soundcloud",
        source_item_id="sc1",
        display_name="hello",
        primary_creator_name="world",
        duration_ms=10500,  # within same 5s bucket
        provider_relevance=0.7,
    )
    result = _deduplicate([spotify_item, sc_item])
    assert len(result) == 1
    assert len(result[0].sources) == 2
    assert result[0].relevance_score == 0.9  # max


def test_deduplicate_keeps_distinct_items():
    a = _make_item(source_item_id="a", display_name="Alpha", duration_ms=1000)
    b = _make_item(source_item_id="b", display_name="Beta", duration_ms=2000)
    result = _deduplicate([a, b])
    assert len(result) == 2


# ---------- _sort_items ----------


def _make_unified(relevance: float, name: str, uid: str = "x") -> UnifiedResultItem:
    return UnifiedResultItem(
        id=uid,
        type="track",
        display_name=name,
        sources=[ResultAttribution(source="spotify", source_item_id="s1")],
        relevance_score=relevance,
    )


def test_sort_items_descending_relevance():
    items = [_make_unified(0.5, "A"), _make_unified(0.9, "B"), _make_unified(0.1, "C")]
    sorted_items = _sort_items(items)
    assert [i.display_name for i in sorted_items] == ["B", "A", "C"]


def test_sort_items_stable_tie_break_by_name():
    items = [_make_unified(0.5, "Zebra", "z"), _make_unified(0.5, "Apple", "a")]
    sorted_items = _sort_items(items)
    assert sorted_items[0].display_name == "Apple"


# ---------- MusicSearchUseCase (with mocked providers) ----------


def _make_mock_provider(
    tracks=None,
    albums=None,
    artists=None,
    raise_exc=None,
):
    class MockProvider:
        async def search_tracks(self, term, limit):
            if raise_exc:
                raise raise_exc
            return tracks or []

        async def search_albums(self, term, limit):
            if raise_exc:
                raise raise_exc
            return albums or []

        async def search_artists(self, term, limit):
            if raise_exc:
                raise raise_exc
            return artists or []

    return MockProvider()


class MockSettings:
    music_search_request_timeout_seconds = 5.0
    music_search_provider_bulkhead_limit = 10
    music_search_spotify_enabled = True
    music_search_soundcloud_enabled = True


def _make_use_case(spotify_provider=None, sc_provider=None, spotify_enabled=True, soundcloud_enabled=True):
    settings = MockSettings()
    settings.music_search_spotify_enabled = spotify_enabled
    settings.music_search_soundcloud_enabled = soundcloud_enabled
    return MusicSearchUseCase(
        spotify_client=spotify_provider or _make_mock_provider(),
        soundcloud_client=sc_provider or _make_mock_provider(),
        settings=settings,
    )


@pytest.mark.anyio
async def test_search_returns_grouped_arrays():
    track = _make_item(source="spotify", source_item_id="t1", display_name="Track One")
    use_case = _make_use_case(spotify_provider=_make_mock_provider(tracks=[track]))
    result = await use_case.search("query")
    assert len(result.tracks) == 1
    assert result.albums == []
    assert result.artists == []


@pytest.mark.anyio
async def test_search_empty_query_raises_validation_error():
    use_case = _make_use_case()
    with pytest.raises(SearchValidationError):
        await use_case.search("   ")


@pytest.mark.anyio
async def test_search_limit_applied_per_type():
    tracks = [_make_item(source="spotify", source_item_id=f"t{i}", display_name=f"Track {i}", duration_ms=i * 1000) for i in range(1, 11)]
    use_case = _make_use_case(spotify_provider=_make_mock_provider(tracks=tracks))
    result = await use_case.search("query", limit=3)
    assert len(result.tracks) <= 3


@pytest.mark.anyio
async def test_search_both_providers_contribute():
    sp_track = _make_item(
        source="spotify",
        source_item_id="sp1",
        display_name="Spotify Only",
        duration_ms=100000,
    )
    sc_track = _make_item(
        source="soundcloud",
        source_item_id="sc1",
        display_name="SoundCloud Only",
        duration_ms=200000,
    )
    use_case = _make_use_case(
        spotify_provider=_make_mock_provider(tracks=[sp_track]),
        sc_provider=_make_mock_provider(tracks=[sc_track]),
    )
    result = await use_case.search("query")
    assert len(result.tracks) == 2


@pytest.mark.anyio
async def test_search_uses_only_soundcloud_when_spotify_disabled():
    sc_track = _make_item(
        source="soundcloud",
        source_item_id="sc1",
        display_name="SoundCloud Only",
        duration_ms=200000,
    )
    use_case = _make_use_case(
        sc_provider=_make_mock_provider(tracks=[sc_track]),
        spotify_enabled=False,
    )
    result = await use_case.search("query")
    assert len(result.tracks) == 1
    assert result.summary.source_statuses["spotify"] == "unavailable"
    assert result.summary.source_statuses["soundcloud"] == "matched"
    assert result.summary.is_partial is True
    assert any("spotify search disabled" in w for w in result.summary.warnings)


@pytest.mark.anyio
async def test_search_uses_only_spotify_when_soundcloud_disabled():
    sp_track = _make_item(
        source="spotify",
        source_item_id="sp1",
        display_name="Spotify Only",
        duration_ms=100000,
    )
    use_case = _make_use_case(
        spotify_provider=_make_mock_provider(tracks=[sp_track]),
        soundcloud_enabled=False,
    )
    result = await use_case.search("query")
    assert len(result.tracks) == 1
    assert result.summary.source_statuses["spotify"] == "matched"
    assert result.summary.source_statuses["soundcloud"] == "unavailable"
    assert result.summary.is_partial is True
    assert any("soundcloud search disabled" in w for w in result.summary.warnings)


@pytest.mark.anyio
async def test_search_partial_when_one_provider_unavailable():
    from backend.domain.music_search.exceptions import ProviderUnavailableError

    sp_track = _make_item(source="spotify", source_item_id="sp1", display_name="Spotify Track")
    use_case = _make_use_case(
        spotify_provider=_make_mock_provider(tracks=[sp_track]),
        sc_provider=_make_mock_provider(raise_exc=ProviderUnavailableError("soundcloud", "down")),
    )
    result = await use_case.search("query")
    assert result.summary.is_partial is True
    assert result.summary.source_statuses["soundcloud"] == "unavailable"
    assert result.summary.source_statuses["spotify"] == "matched"
    assert len(result.tracks) == 1


@pytest.mark.anyio
async def test_search_raises_when_all_providers_unavailable():
    from backend.domain.music_search.exceptions import ProviderUnavailableError

    use_case = _make_use_case(
        spotify_provider=_make_mock_provider(raise_exc=ProviderUnavailableError("spotify", "down")),
        sc_provider=_make_mock_provider(raise_exc=ProviderUnavailableError("soundcloud", "down")),
    )
    with pytest.raises(AllProvidersUnavailableError):
        await use_case.search("query")


@pytest.mark.anyio
async def test_search_raises_when_all_providers_disabled():
    use_case = _make_use_case(spotify_enabled=False, soundcloud_enabled=False)
    with pytest.raises(AllProvidersUnavailableError):
        await use_case.search("query")


# ---------- _call_provider error paths ----------


@pytest.mark.anyio
async def test_call_provider_timeout_returns_unavailable():
    import asyncio

    class TimeoutProvider:
        async def search_tracks(self, term, limit):
            await asyncio.sleep(100)
            return []  # pragma: no cover

        async def search_albums(self, term, limit):
            await asyncio.sleep(100)
            return []  # pragma: no cover

        async def search_artists(self, term, limit):
            await asyncio.sleep(100)
            return []  # pragma: no cover

    use_case = _make_use_case()
    use_case._timeout = 0.01  # Very short timeout
    items, status, warn = await use_case._call_provider("test", TimeoutProvider(), "q", 5)
    assert status == "unavailable"
    assert warn is not None


@pytest.mark.anyio
async def test_call_provider_generic_exception_returns_unavailable():
    """Unexpected non-provider exception in wait_for is caught and returns unavailable."""

    class BrokenProvider:
        async def search_tracks(self, term, limit):
            raise RuntimeError("totally broken")

        async def search_albums(self, term, limit):
            raise RuntimeError("totally broken")

        async def search_artists(self, term, limit):
            raise RuntimeError("totally broken")

    use_case = _make_use_case()
    items, status, warn = await use_case._call_provider("test", BrokenProvider(), "q", 5)
    assert status == "unavailable"
    assert warn is not None


@pytest.mark.anyio
async def test_call_provider_subcall_generic_exception_returns_unavailable():
    """Non-ProviderUnavailableError sub-call exception is treated as service error."""

    class PartiallyBrokenProvider:
        async def search_tracks(self, term, limit):
            raise ValueError("bad value")

        async def search_albums(self, term, limit):
            return []

        async def search_artists(self, term, limit):
            return []

    use_case = _make_use_case()
    items, status, warn = await use_case._call_provider("test", PartiallyBrokenProvider(), "q", 5)
    assert status == "unavailable"


# ---------- _duration_bucket ----------


def test_duration_bucket_none():
    from backend.application.music_search.use_cases import _duration_bucket

    assert _duration_bucket(None) == "none"


def test_duration_bucket_value():
    from backend.application.music_search.use_cases import _duration_bucket

    assert _duration_bucket(10000) == "2"
    assert _duration_bucket(0) == "0"


# ---------- Entity validators ----------


def test_source_result_item_rejects_zero_duration():
    with pytest.raises(Exception):
        SourceResultItem(
            source="spotify",
            source_item_id="x",
            type="track",
            display_name="Song",
            duration_ms=0,
        )


def test_source_result_item_rejects_negative_duration():
    with pytest.raises(Exception):
        SourceResultItem(
            source="spotify",
            source_item_id="x",
            type="track",
            display_name="Song",
            duration_ms=-1,
        )


def test_unified_result_item_rejects_empty_sources():
    with pytest.raises(Exception):
        UnifiedResultItem(
            id="x",
            type="track",
            display_name="Song",
            sources=[],
            relevance_score=0.5,
        )


def test_unified_result_item_rejects_non_positive_duration():
    with pytest.raises(Exception):
        UnifiedResultItem(
            id="x",
            type="track",
            display_name="Song",
            sources=[ResultAttribution(source="spotify", source_item_id="s1")],
            relevance_score=0.5,
            duration_ms=-100,
        )
