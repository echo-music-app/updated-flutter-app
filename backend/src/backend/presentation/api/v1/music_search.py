"""POST /v1/search/music unified music search endpoint."""

import logging
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, Field, field_validator

from backend.application.music_search.use_cases import (
    _LIMIT_DEFAULT,
    _LIMIT_MAX,
    _LIMIT_MIN,
    MusicSearchUseCase,
)
from backend.core.config import Settings, get_settings
from backend.core.deps import get_current_user
from backend.domain.music_search.exceptions import AllProvidersUnavailableError, SearchValidationError
from backend.infrastructure.music_providers.soundcloud_search_client import SoundCloudSearchClient
from backend.infrastructure.music_providers.spotify_search_client import SpotifySearchClient
from backend.infrastructure.persistence.models.user import User

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/search", tags=["music-search"])


# ---------- Request / Response DTOs ----------


class MusicSearchRequest(BaseModel):
    q: str
    limit: int = Field(default=_LIMIT_DEFAULT, ge=_LIMIT_MIN, le=_LIMIT_MAX)

    @field_validator("q")
    @classmethod
    def q_must_not_be_blank(cls, v: str) -> str:
        if not v.strip():
            raise ValueError("Search query must not be empty")
        return v


class ResultAttributionDTO(BaseModel):
    source: Literal["spotify", "soundcloud"]
    source_item_id: str
    source_url: str | None


class UnifiedResultItemDTO(BaseModel):
    id: str
    type: Literal["track", "album", "artist"]
    display_name: str
    primary_creator_name: str | None
    duration_ms: int | None
    playable_link: str | None
    artwork_url: str | None
    sources: list[ResultAttributionDTO]
    relevance_score: float


class SearchResponseSummaryDTO(BaseModel):
    total_count: int
    per_type_counts: dict[str, int]
    per_source_counts: dict[str, int]
    source_statuses: dict[str, Literal["matched", "no_matches", "unavailable"]]
    is_partial: bool
    warnings: list[str]


class MusicSearchResponseDTO(BaseModel):
    query: str
    limit: int
    tracks: list[UnifiedResultItemDTO]
    albums: list[UnifiedResultItemDTO]
    artists: list[UnifiedResultItemDTO]
    summary: SearchResponseSummaryDTO


# ---------- Dependency wiring ----------


def get_music_search_use_case(settings: Settings = Depends(get_settings)) -> MusicSearchUseCase:
    spotify_client = SpotifySearchClient(settings)
    soundcloud_client = SoundCloudSearchClient(settings)
    return MusicSearchUseCase(
        spotify_client=spotify_client,
        soundcloud_client=soundcloud_client,
        settings=settings,
    )


# ---------- Endpoint ----------


@router.post("/music", response_model=MusicSearchResponseDTO)
async def search_music(
    body: MusicSearchRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    use_case: MusicSearchUseCase = Depends(get_music_search_use_case),
) -> MusicSearchResponseDTO:
    """Search for music across Spotify and SoundCloud."""
    accept_language = request.headers.get("Accept-Language", "en")
    logger.info("music_search user=%s lang=%s", current_user.id, accept_language)

    try:
        result = await use_case.search(body.q, body.limit)
    except SearchValidationError as exc:
        raise HTTPException(status_code=422, detail=str(exc))
    except AllProvidersUnavailableError:
        raise HTTPException(status_code=503, detail="Music search service unavailable")

    def _map_item(item) -> UnifiedResultItemDTO:
        return UnifiedResultItemDTO(
            id=item.id,
            type=item.type,
            display_name=item.display_name,
            primary_creator_name=item.primary_creator_name,
            duration_ms=item.duration_ms,
            playable_link=item.playable_link,
            artwork_url=item.artwork_url,
            sources=[
                ResultAttributionDTO(
                    source=s.source,
                    source_item_id=s.source_item_id,
                    source_url=s.source_url,
                )
                for s in item.sources
            ],
            relevance_score=item.relevance_score,
        )

    return MusicSearchResponseDTO(
        query=result.query,
        limit=result.limit,
        tracks=[_map_item(i) for i in result.tracks],
        albums=[_map_item(i) for i in result.albums],
        artists=[_map_item(i) for i in result.artists],
        summary=SearchResponseSummaryDTO(
            total_count=result.summary.total_count,
            per_type_counts=result.summary.per_type_counts,
            per_source_counts=result.summary.per_source_counts,
            source_statuses=result.summary.source_statuses,
            is_partial=result.summary.is_partial,
            warnings=result.summary.warnings,
        ),
    )
