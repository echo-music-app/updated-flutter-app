"""Provider client protocols and port interfaces for music search."""

from typing import Protocol

from backend.domain.music_search.entities import SourceResultItem


class MusicProviderClient(Protocol):
    """Protocol for music provider search adapters."""

    async def search_tracks(self, term: str, limit: int) -> list[SourceResultItem]: ...

    async def search_albums(self, term: str, limit: int) -> list[SourceResultItem]: ...

    async def search_artists(self, term: str, limit: int) -> list[SourceResultItem]: ...
