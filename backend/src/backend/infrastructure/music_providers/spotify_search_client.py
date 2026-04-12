"""Spotify search adapter implementing MusicProviderClient protocol."""

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

_SEARCH_URL = "https://api.spotify.com/v1/search"


class SpotifySearchClient:
    """Adapts Spotify Web API search for unified music search."""

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

            client_id = self._settings.spotify_client_id
            client_secret = self._settings.spotify_client_secret.get_secret_value()

            async with httpx.AsyncClient() as http:
                resp = await http.post(
                    self._settings.spotify_token_url,
                    data={"grant_type": "client_credentials", "client_id": client_id, "client_secret": client_secret},
                    timeout=10.0,
                    headers={
                        "Content-Type": "application/x-www-form-urlencoded",
                    },
                )

            if resp.status_code in (401, 403):
                raise ProviderAuthError("spotify", f"token request returned {resp.status_code}")
            if resp.status_code != 200:
                raise ProviderUnavailableError("spotify", f"token request returned {resp.status_code}")

            payload = resp.json()
            self._token = payload["access_token"]
            self._token_expires_at = time.monotonic() + payload.get("expires_in", 3600)
            return self._token  # type: ignore[return-value]

    async def _search(self, term: str, search_type: str, limit: int) -> list[dict[str, Any]]:
        token = await self._acquire_token()
        market = self._settings.spotify_search_default_market
        params: dict[str, Any] = {
            "q": term,
            "type": search_type,
            "limit": limit,
            "offset": 0,
        }
        if market:
            params["market"] = market

        async with httpx.AsyncClient() as http:
            resp = await http.get(
                _SEARCH_URL,
                headers={"Authorization": f"Bearer {token}"},
                params=params,
                timeout=self._settings.music_search_request_timeout_seconds,
            )

        if resp.status_code == 401:
            # Token may have expired — invalidate and raise so retry can happen at orchestration level
            self._token = None
            raise ProviderAuthError("spotify", "search returned 401")
        if resp.status_code == 403:
            raise ProviderAuthError("spotify", "search returned 403")
        if resp.status_code == 429:
            raise ProviderRateLimitError("spotify", "rate limited (429)")
        if resp.status_code >= 500:
            raise ProviderUnavailableError("spotify", f"server error {resp.status_code}")
        if resp.status_code != 200:
            raise ProviderUnavailableError("spotify", f"unexpected status {resp.status_code}")

        return resp.json()

    @staticmethod
    def _map_track(raw: dict[str, Any]) -> SourceResultItem:
        artists = raw.get("artists") or []
        creator = artists[0]["name"] if artists else None
        images = (raw.get("album") or {}).get("images") or []
        artwork = images[0]["url"] if images else None
        return SourceResultItem(
            source="spotify",
            source_item_id=f"spotify:track:{raw['id']}",
            type="track",
            display_name=raw["name"],
            primary_creator_name=creator,
            duration_ms=raw.get("duration_ms"),
            playable_link=raw.get("external_urls", {}).get("spotify"),
            artwork_url=artwork,
            provider_relevance=raw.get("popularity", 0) / 100.0,
        )

    @staticmethod
    def _map_album(raw: dict[str, Any]) -> SourceResultItem:
        artists = raw.get("artists") or []
        creator = artists[0]["name"] if artists else None
        images = raw.get("images") or []
        artwork = images[0]["url"] if images else None
        return SourceResultItem(
            source="spotify",
            source_item_id=f"spotify:album:{raw['id']}",
            type="album",
            display_name=raw["name"],
            primary_creator_name=creator,
            duration_ms=None,
            playable_link=raw.get("external_urls", {}).get("spotify"),
            artwork_url=artwork,
            provider_relevance=raw.get("popularity", 0) / 100.0,
        )

    @staticmethod
    def _map_artist(raw: dict[str, Any]) -> SourceResultItem:
        images = raw.get("images") or []
        artwork = images[0]["url"] if images else None
        return SourceResultItem(
            source="spotify",
            source_item_id=f"spotify:artist:{raw['id']}",
            type="artist",
            display_name=raw["name"],
            primary_creator_name=None,
            duration_ms=None,
            playable_link=raw.get("external_urls", {}).get("spotify"),
            artwork_url=artwork,
            provider_relevance=raw.get("popularity", 0) / 100.0,
        )

    async def search_tracks(self, term: str, limit: int) -> list[SourceResultItem]:
        payload = await self._search(term, "track", limit)
        return [self._map_track(t) for t in (payload.get("tracks") or {}).get("items") or []]

    async def search_albums(self, term: str, limit: int) -> list[SourceResultItem]:
        payload = await self._search(term, "album", limit)
        return [self._map_album(a) for a in (payload.get("albums") or {}).get("items") or []]

    async def search_artists(self, term: str, limit: int) -> list[SourceResultItem]:
        payload = await self._search(term, "artist", limit)
        return [self._map_artist(a) for a in (payload.get("artists") or {}).get("items") or []]
