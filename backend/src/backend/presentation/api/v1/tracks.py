from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.spotify.use_cases import SpotifyUseCases
from backend.core.config import get_settings
from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.domain.spotify.exceptions import SpotifyApiError
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.spotify_credentials_repository import (
    SqlAlchemySpotifyCredentialsRepository,
)
from backend.infrastructure.persistence.repositories.token_repository import SqlAlchemyTokenRepository
from backend.infrastructure.spotify.client import SpotifyClient

router = APIRouter(prefix="/tracks", tags=["tracks"])


class TrackResponseModel(BaseModel):
    id: str
    uri: str
    name: str
    artist_name: str
    album_art_url: str
    duration_ms: int


def get_spotify_use_cases(db: AsyncSession = Depends(get_db_session)) -> SpotifyUseCases:
    return SpotifyUseCases(
        creds_repo=SqlAlchemySpotifyCredentialsRepository(db),
        token_repo=SqlAlchemyTokenRepository(db),
        spotify_client=SpotifyClient(),
        settings=get_settings(),
    )


@router.get("/{track_id}", response_model=TrackResponseModel)
async def get_track(
    track_id: str,
    request: Request,
    current_user: User = Depends(get_current_user),
    use_cases: SpotifyUseCases = Depends(get_spotify_use_cases),
):
    """Fetch track metadata from Spotify Web API via the Echo backend."""
    try:
        track = await use_cases.get_track(current_user.id, track_id)
    except SpotifyApiError as e:
        raise HTTPException(status_code=e.status_code, detail=e.detail)
    except Exception:
        raise HTTPException(status_code=503, detail="Spotify service unavailable")

    return TrackResponseModel(
        id=track.id,
        uri=track.uri,
        name=track.name,
        artist_name=track.artist_name,
        album_art_url=track.album_art_url,
        duration_ms=track.duration_ms,
    )
