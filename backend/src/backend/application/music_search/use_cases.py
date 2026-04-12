"""Music search use case orchestration."""

import asyncio
import hashlib
import logging
import re
import unicodedata
from typing import Literal

from backend.application.music_search.ports import MusicProviderClient
from backend.core.config import Settings
from backend.domain.music_search.entities import (
    ResultAttribution,
    SearchResponseSummary,
    SourceResultItem,
    UnifiedMusicSearchResponse,
    UnifiedResultItem,
)
from backend.domain.music_search.exceptions import (
    AllProvidersUnavailableError,
    ProviderUnavailableError,
)

logger = logging.getLogger(__name__)

_LIMIT_MIN = 1
_LIMIT_MAX = 10
_LIMIT_DEFAULT = 10


def normalize_query(q: str) -> str:
    """Strip leading/trailing whitespace while preserving internal punctuation and non-Latin characters."""
    return q.strip()


def validate_limit(limit: int) -> int:
    """Validate and return per-type limit within allowed bounds."""
    if limit < _LIMIT_MIN or limit > _LIMIT_MAX:
        raise ValueError(f"limit must be between {_LIMIT_MIN} and {_LIMIT_MAX}")
    return limit


def _normalize_for_key(text: str) -> str:
    """Lowercase + strip accents + collapse whitespace for dedup key generation."""
    nfkd = unicodedata.normalize("NFKD", text.lower())
    ascii_only = "".join(c for c in nfkd if not unicodedata.combining(c))
    return re.sub(r"\s+", " ", ascii_only).strip()


def _duration_bucket(duration_ms: int | None) -> str:
    """Bucket duration_ms into 5-second bins for fuzzy track deduplication."""
    if duration_ms is None:
        return "none"
    return str(duration_ms // 5000)


def _track_dedup_key(item: SourceResultItem) -> str:
    name = _normalize_for_key(item.display_name)
    creator = _normalize_for_key(item.primary_creator_name or "")
    bucket = _duration_bucket(item.duration_ms)
    return f"track:{name}:{creator}:{bucket}"


def _album_dedup_key(item: SourceResultItem) -> str:
    name = _normalize_for_key(item.display_name)
    creator = _normalize_for_key(item.primary_creator_name or "")
    return f"album:{name}:{creator}"


def _artist_dedup_key(item: SourceResultItem) -> str:
    name = _normalize_for_key(item.display_name)
    return f"artist:{name}"


_DEDUP_KEY_FN = {
    "track": _track_dedup_key,
    "album": _album_dedup_key,
    "artist": _artist_dedup_key,
}


def _stable_id(dedup_key: str) -> str:
    return hashlib.sha1(dedup_key.encode()).hexdigest()[:16]


def _deduplicate(items: list[SourceResultItem]) -> list[UnifiedResultItem]:
    """Merge provider hits by dedup key while preserving source attribution."""
    groups: dict[str, list[SourceResultItem]] = {}
    key_fn = _DEDUP_KEY_FN[items[0].type] if items else None
    for item in items:
        key = key_fn(item)  # type: ignore[misc]
        groups.setdefault(key, []).append(item)

    result: list[UnifiedResultItem] = []
    for key, group in groups.items():
        primary = group[0]
        sources = [
            ResultAttribution(
                source=i.source,
                source_item_id=i.source_item_id,
                source_url=i.playable_link,
            )
            for i in group
        ]
        relevance = max((i.provider_relevance or 0.0) for i in group)
        result.append(
            UnifiedResultItem(
                id=_stable_id(key),
                type=primary.type,
                display_name=primary.display_name,
                primary_creator_name=primary.primary_creator_name,
                duration_ms=primary.duration_ms,
                playable_link=primary.playable_link,
                artwork_url=primary.artwork_url,
                sources=sources,
                relevance_score=relevance,
            )
        )
    return result


def _sort_items(items: list[UnifiedResultItem]) -> list[UnifiedResultItem]:
    """Sort by descending relevance, then by normalized display_name, then by id."""
    return sorted(
        items,
        key=lambda x: (-x.relevance_score, _normalize_for_key(x.display_name), x.id),
    )


ProviderStatus = Literal["matched", "no_matches", "unavailable"]


class MusicSearchUseCase:
    """Orchestrates parallel provider fanout, normalization, dedupe, and summary."""

    def __init__(
        self,
        spotify_client: MusicProviderClient,
        soundcloud_client: MusicProviderClient,
        settings: Settings,
    ) -> None:
        self._spotify = spotify_client
        self._soundcloud = soundcloud_client
        self._spotify_enabled = settings.music_search_spotify_enabled
        self._soundcloud_enabled = settings.music_search_soundcloud_enabled
        self._timeout = settings.music_search_request_timeout_seconds
        self._semaphore = asyncio.Semaphore(settings.music_search_provider_bulkhead_limit)

    async def _call_provider(
        self,
        provider_name: str,
        client: MusicProviderClient,
        term: str,
        limit: int,
    ) -> tuple[list[SourceResultItem], ProviderStatus, str | None]:
        """Call all three search methods on a provider with bulkhead and timeout.

        Returns (items, status, warning_message).
        """
        async with self._semaphore:
            try:
                tracks, albums, artists = await asyncio.wait_for(
                    asyncio.gather(
                        client.search_tracks(term, limit),
                        client.search_albums(term, limit),
                        client.search_artists(term, limit),
                        return_exceptions=True,
                    ),
                    timeout=self._timeout,
                )
            except TimeoutError:
                logger.warning("provider=%s timeout after %.1fs", provider_name, self._timeout)
                return [], "unavailable", f"{provider_name} request timed out"

        # If any sub-call raised a provider-level error, treat the whole provider as unavailable
        for result in [tracks, albums, artists]:
            if isinstance(result, ProviderUnavailableError):
                logger.warning("provider=%s unavailable: %s", provider_name, result.reason)
                return [], "unavailable", result.reason
            if isinstance(result, Exception):
                logger.error("provider=%s unexpected sub-call error: %s", provider_name, result)
                return [], "unavailable", f"{provider_name} service error"

        items: list[SourceResultItem] = []
        for result in [tracks, albums, artists]:
            items.extend(result)  # type: ignore[arg-type]

        status: ProviderStatus = "matched" if items else "no_matches"
        return items, status, None

    async def search(self, q: str, limit: int = _LIMIT_DEFAULT) -> UnifiedMusicSearchResponse:
        """Execute unified music search across all providers."""
        term = normalize_query(q)
        if not term:
            from backend.domain.music_search.exceptions import SearchValidationError

            raise SearchValidationError("Query must not be empty")
        limit = validate_limit(limit)

        logger.info("music_search query=%r limit=%d", term, limit)

        spotify_items: list[SourceResultItem] = []
        sc_items: list[SourceResultItem] = []
        spotify_status: ProviderStatus = "unavailable"
        sc_status: ProviderStatus = "unavailable"
        spotify_warn: str | None = None
        sc_warn: str | None = None

        if self._spotify_enabled and self._soundcloud_enabled:
            spotify_task = asyncio.create_task(self._call_provider("spotify", self._spotify, term, limit))
            soundcloud_task = asyncio.create_task(self._call_provider("soundcloud", self._soundcloud, term, limit))
            (spotify_items, spotify_status, spotify_warn), (sc_items, sc_status, sc_warn) = await asyncio.gather(
                spotify_task,
                soundcloud_task,
            )
        else:
            if self._spotify_enabled:
                spotify_items, spotify_status, spotify_warn = await self._call_provider("spotify", self._spotify, term, limit)
            else:
                spotify_warn = "spotify search disabled by configuration"
                logger.info("music_search provider=spotify disabled_by_configuration")

            if self._soundcloud_enabled:
                sc_items, sc_status, sc_warn = await self._call_provider("soundcloud", self._soundcloud, term, limit)
            else:
                sc_warn = "soundcloud search disabled by configuration"
                logger.info("music_search provider=soundcloud disabled_by_configuration")

        logger.info(
            "music_search providers done spotify=%s soundcloud=%s",
            spotify_status,
            sc_status,
        )

        if spotify_status == "unavailable" and sc_status == "unavailable":
            raise AllProvidersUnavailableError({"spotify": spotify_warn or "unavailable", "soundcloud": sc_warn or "unavailable"})

        all_items = spotify_items + sc_items

        def _group_and_merge(item_type: str) -> list[UnifiedResultItem]:
            typed = [i for i in all_items if i.type == item_type]
            if not typed:
                return []
            merged = _deduplicate(typed)
            return _sort_items(merged)[:limit]

        tracks = _group_and_merge("track")
        albums = _group_and_merge("album")
        artists = _group_and_merge("artist")

        is_partial = spotify_status == "unavailable" or sc_status == "unavailable"
        warnings: list[str] = []
        if spotify_warn:
            warnings.append(spotify_warn)
        if sc_warn:
            warnings.append(sc_warn)

        spotify_count = sum(1 for i in [*tracks, *albums, *artists] if any(s.source == "spotify" for s in i.sources))
        sc_count = sum(1 for i in [*tracks, *albums, *artists] if any(s.source == "soundcloud" for s in i.sources))

        summary = SearchResponseSummary(
            total_count=len(tracks) + len(albums) + len(artists),
            per_type_counts={
                "tracks": len(tracks),
                "albums": len(albums),
                "artists": len(artists),
            },
            per_source_counts={"spotify": spotify_count, "soundcloud": sc_count},
            source_statuses={"spotify": spotify_status, "soundcloud": sc_status},
            is_partial=is_partial,
            warnings=warnings,
        )

        return UnifiedMusicSearchResponse(
            query=term,
            limit=limit,
            tracks=tracks,
            albums=albums,
            artists=artists,
            summary=summary,
        )
