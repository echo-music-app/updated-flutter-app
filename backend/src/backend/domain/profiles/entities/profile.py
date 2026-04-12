"""Profile domain entities (DTOs / value objects)."""

import uuid
from dataclasses import dataclass
from datetime import datetime


@dataclass(slots=True)
class PublicUserProfile:
    id: uuid.UUID
    username: str
    bio: str | None
    preferred_genres: list[str]
    is_artist: bool
    created_at: datetime


@dataclass(slots=True)
class MeProfile:
    id: uuid.UUID
    email: str
    username: str
    bio: str | None
    preferred_genres: list[str]
    status: str
    is_artist: bool
    created_at: datetime
    updated_at: datetime


@dataclass(slots=True)
class MeProfilePatch:
    username: str | None = None
    bio: str | None = None
    preferred_genres: list[str] | None = None
