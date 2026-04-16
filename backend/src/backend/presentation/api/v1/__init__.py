from fastapi import APIRouter

from backend.presentation.api.v1.auth import router as auth_router
from backend.presentation.api.v1.friends import router as friends_router
from backend.presentation.api.v1.health import router as health_router
from backend.presentation.api.v1.messages import router as messages_router
from backend.presentation.api.v1.music_search import router as music_search_router
from backend.presentation.api.v1.posts import router as posts_router
from backend.presentation.api.v1.profiles import router as profiles_router
from backend.presentation.api.v1.spotify_auth import router as spotify_auth_router
from backend.presentation.api.v1.tracks import router as tracks_router

v1_router = APIRouter()
v1_router.include_router(health_router)
v1_router.include_router(auth_router)
v1_router.include_router(friends_router)
v1_router.include_router(spotify_auth_router)
v1_router.include_router(tracks_router)
v1_router.include_router(posts_router)
v1_router.include_router(profiles_router)
v1_router.include_router(music_search_router)
v1_router.include_router(messages_router)
