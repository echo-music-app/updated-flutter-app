"""Admin friend relationship domain entities."""

import uuid
from dataclasses import dataclass
from enum import StrEnum


class RelationshipStatus(StrEnum):
    pending = "pending"
    active = "active"
    blocked = "blocked"
    removed = "removed"


@dataclass(frozen=True)
class FriendRelationshipRecord:
    id: uuid.UUID
    user_a_id: uuid.UUID
    user_b_id: uuid.UUID
    status: RelationshipStatus
    created_at: str
    updated_at: str
