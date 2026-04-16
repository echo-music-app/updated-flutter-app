"""Profile domain entities (DTOs / value objects)."""

import uuid
from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class PublicUserProfile:
    id: uuid.UUID
    username: str
    avatar_path: str | None
    bio: str | None
    preferred_genres: list[str]
    is_artist: bool
    followers_count: int
    following_count: int
    created_at: datetime


@dataclass(slots=True)
class MeProfile:
    id: uuid.UUID
    email: str
    username: str
    avatar_path: str | None
    bio: str | None
    preferred_genres: list[str]
    status: str
    is_artist: bool
    followers_count: int
    following_count: int
    created_at: datetime
    updated_at: datetime


@dataclass(slots=True)
class MeProfilePatch:
    username: str | None = None
    bio: str | None = None
    preferred_genres: list[str] | None = None
