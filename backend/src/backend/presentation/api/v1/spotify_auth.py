from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.spotify.use_cases import SpotifyUseCases
from backend.core.config import get_settings
from backend.core.database import get_db_session
from backend.core.decorators import public_endpoint
from backend.core.deps import get_current_user
from backend.domain.spotify.exceptions import SpotifyAuthError
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.spotify_credentials_repository import (
    SqlAlchemySpotifyCredentialsRepository,
)
from backend.infrastructure.persistence.repositories.token_repository import SqlAlchemyTokenRepository
from backend.infrastructure.spotify.client import SpotifyClient

router = APIRouter(prefix="/auth/spotify", tags=["spotify-auth"])


class SpotifyTokenRequest(BaseModel):
    code: str
    code_verifier: str
    redirect_uri: str

    @field_validator("code_verifier")
    @classmethod
    def validate_code_verifier(cls, v: str) -> str:
        if len(v) < 43 or len(v) > 128:
            raise ValueError("code_verifier must be 43-128 characters")
        return v

    @field_validator("redirect_uri")
    @classmethod
    def validate_redirect_uri(cls, v: str) -> str:
        if not v.startswith("https://"):
            raise ValueError("redirect_uri must use HTTPS")
        return v


class SpotifyRefreshRequest(BaseModel):
    refresh_token: str


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


def get_spotify_use_cases(db: AsyncSession = Depends(get_db_session)) -> SpotifyUseCases:
    return SpotifyUseCases(
        creds_repo=SqlAlchemySpotifyCredentialsRepository(db),
        token_repo=SqlAlchemyTokenRepository(db),
        spotify_client=SpotifyClient(),
        settings=get_settings(),
    )


@router.post("/token", response_model=TokenResponse)
async def spotify_token_exchange(
    body: SpotifyTokenRequest,
    request: Request,
    current_user: User = Depends(get_current_user),
    use_cases: SpotifyUseCases = Depends(get_spotify_use_cases),
):
    """Exchange a Spotify authorization code for Echo tokens."""
    try:
        token_pair = await use_cases.exchange_code(
            user_id=current_user.id,
            code=body.code,
            code_verifier=body.code_verifier,
            redirect_uri=body.redirect_uri,
        )
    except SpotifyAuthError as e:
        raise HTTPException(status_code=401, detail=str(e))
    except Exception:
        raise HTTPException(status_code=503, detail="Spotify service unavailable")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/refresh", response_model=TokenResponse)
@public_endpoint
async def spotify_refresh(
    body: SpotifyRefreshRequest,
    use_cases: SpotifyUseCases = Depends(get_spotify_use_cases),
):
    """Refresh Echo tokens (proactively refreshes Spotify token if near expiry)."""
    try:
        token_pair = await use_cases.refresh_token(body.refresh_token)
    except SpotifyAuthError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")
    except Exception:
        raise HTTPException(status_code=503, detail="Spotify service unavailable")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )
