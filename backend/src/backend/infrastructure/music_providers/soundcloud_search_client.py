"""SoundCloud search adapter implementing MusicProviderClient protocol."""

import asyncio
import logging
import time
from typing import Any

import httpx

from backend.core.config import Settings
from backend.domain.music_search.entities import SourceResultItem
from backend.domain.music_search.exceptions import (
    ProviderAuthError,
    ProviderRateLimitError,
    ProviderUnavailableError,
)

logger = logging.getLogger(__name__)

_TRACKS_URL = "https://api.soundcloud.com/tracks"
_PLAYLISTS_URL = "https://api.soundcloud.com/playlists"
_USERS_URL = "https://api.soundcloud.com/users"


class SoundCloudSearchClient:
    """Adapts SoundCloud API search for unified music search."""

    def __init__(self, settings: Settings) -> None:
        self._settings = settings
        self._token: str | None = None
        self._token_expires_at: float = 0.0
        self._lock = asyncio.Lock()

    def _is_token_valid(self) -> bool:
        return self._token is not None and time.monotonic() < self._token_expires_at - 10

    async def _acquire_token(self) -> str:
        async with self._lock:
            if self._is_token_valid():
                return self._token  # type: ignore[return-value]

            async with httpx.AsyncClient() as http:
                resp = await http.post(
                    self._settings.soundcloud_token_url,
                    data={
                        "grant_type": "client_credentials",
                        "client_id": self._settings.soundcloud_client_id,
                        "client_secret": self._settings.soundcloud_client_secret.get_secret_value(),
                    },
                    timeout=10.0,
                )

            if resp.status_code in (401, 403):
                raise ProviderAuthError("soundcloud", f"token request returned {resp.status_code}")
            if resp.status_code != 200:
                raise ProviderUnavailableError("soundcloud", f"token request returned {resp.status_code}")

            payload = resp.json()
            self._token = payload["access_token"]
            self._token_expires_at = time.monotonic() + payload.get("expires_in", 3600)
            return self._token  # type: ignore[return-value]

    async def _get(self, url: str, term: str, limit: int) -> list[dict[str, Any]]:
        token = await self._acquire_token()
        params = {
            "q": term,
            "limit": limit,
            "linked_partitioning": "true",
        }
        async with httpx.AsyncClient() as http:
            resp = await http.get(
                url,
                headers={"Authorization": f"OAuth {token}"},
                params=params,
                timeout=self._settings.music_search_request_timeout_seconds,
            )

        if resp.status_code == 401:
            self._token = None
            raise ProviderAuthError("soundcloud", "search returned 401")
        if resp.status_code == 429:
            raise ProviderRateLimitError("soundcloud", "rate limited (429)")
        if resp.status_code >= 500:
            raise ProviderUnavailableError("soundcloud", f"server error {resp.status_code}")
        if resp.status_code != 200:
            raise ProviderUnavailableError("soundcloud", f"unexpected status {resp.status_code}")

        return resp.json().get("collection") or []

    @staticmethod
    def _map_track(raw: dict[str, Any]) -> SourceResultItem:
        user = raw.get("user") or {}
        artwork = raw.get("artwork_url")
        return SourceResultItem(
            source="soundcloud",
            source_item_id=f"soundcloud:tracks:{raw['id']}",
            type="track",
            display_name=raw["title"],
            primary_creator_name=user.get("username"),
            duration_ms=raw.get("duration"),
            playable_link=raw.get("permalink_url"),
            artwork_url=artwork,
            provider_relevance=None,
        )

    @staticmethod
    def _map_album(raw: dict[str, Any]) -> SourceResultItem:
        user = raw.get("user") or {}
        artwork = raw.get("artwork_url")
        return SourceResultItem(
            source="soundcloud",
            source_item_id=f"soundcloud:playlists:{raw['id']}",
            type="album",
            display_name=raw["title"],
            primary_creator_name=user.get("username"),
            duration_ms=None,
            playable_link=raw.get("permalink_url"),
            artwork_url=artwork,
            provider_relevance=None,
        )

    @staticmethod
    def _map_artist(raw: dict[str, Any]) -> SourceResultItem:
        artwork = raw.get("avatar_url")
        return SourceResultItem(
            source="soundcloud",
            source_item_id=f"soundcloud:users:{raw['id']}",
            type="artist",
            display_name=raw.get("username") or raw.get("full_name") or "",
            primary_creator_name=None,
            duration_ms=None,
            playable_link=raw.get("permalink_url"),
            artwork_url=artwork,
            provider_relevance=None,
        )

    async def search_tracks(self, term: str, limit: int) -> list[SourceResultItem]:
        items = await self._get(_TRACKS_URL, term, limit)
        return [self._map_track(i) for i in items]

    async def search_albums(self, term: str, limit: int) -> list[SourceResultItem]:
        items = await self._get(_PLAYLISTS_URL, term, limit)
        return [self._map_album(i) for i in items]

    async def search_artists(self, term: str, limit: int) -> list[SourceResultItem]:
        items = await self._get(_USERS_URL, term, limit)
        return [self._map_artist(i) for i in items]
