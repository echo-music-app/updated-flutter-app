"""Domain entities for unified music search."""

from typing import Literal

from pydantic import BaseModel, field_validator


class SourceResultItem(BaseModel):
    """Provider-normalized result from a single music provider."""

    source: Literal["spotify", "soundcloud"]
    source_item_id: str
    type: Literal["track", "album", "artist"]
    display_name: str
    primary_creator_name: str | None = None
    duration_ms: int | None = None
    playable_link: str | None = None
    artwork_url: str | None = None
    provider_relevance: float | None = None

    @field_validator("duration_ms")
    @classmethod
    def duration_must_be_positive(cls, v: int | None) -> int | None:
        if v is not None and v <= 0:
            raise ValueError("duration_ms must be positive")
        return v


class ResultAttribution(BaseModel):
    """Provenance record for a deduplicated unified item."""

    source: Literal["spotify", "soundcloud"]
    source_item_id: str
    source_url: str | None = None


class UnifiedResultItem(BaseModel):
    """A normalized, deduplicated search result combining one or more provider hits."""

    id: str
    type: Literal["track", "album", "artist"]
    display_name: str
    primary_creator_name: str | None = None
    duration_ms: int | None = None
    playable_link: str | None = None
    artwork_url: str | None = None
    sources: list[ResultAttribution]
    relevance_score: float

    @field_validator("sources")
    @classmethod
    def sources_must_be_non_empty(cls, v: list[ResultAttribution]) -> list[ResultAttribution]:
        if not v:
            raise ValueError("sources must contain at least one attribution")
        return v

    @field_validator("duration_ms")
    @classmethod
    def duration_must_be_positive(cls, v: int | None) -> int | None:
        if v is not None and v <= 0:
            raise ValueError("duration_ms must be positive")
        return v


class SourceSearchStatus(BaseModel):
    """Per-provider status summary for a search operation."""

    source: Literal["spotify", "soundcloud"]
    status: Literal["matched", "no_matches", "unavailable"]
    count: int
    message: str | None = None


class SearchResponseSummary(BaseModel):
    """Aggregated summary metadata for a unified search response."""

    total_count: int
    per_type_counts: dict[str, int]
    per_source_counts: dict[str, int]
    source_statuses: dict[str, Literal["matched", "no_matches", "unavailable"]]
    is_partial: bool
    warnings: list[str]


class UnifiedMusicSearchResponse(BaseModel):
    """Full unified search response payload."""

    query: str
    limit: int
    tracks: list[UnifiedResultItem]
    albums: list[UnifiedResultItem]
    artists: list[UnifiedResultItem]
    summary: SearchResponseSummary
