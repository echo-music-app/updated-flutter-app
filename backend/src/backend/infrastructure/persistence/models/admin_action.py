import enum
import uuid
from datetime import datetime

from sqlalchemy import Index, String
from sqlalchemy.dialects.postgresql import JSONB, UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base


class AdminEntityType(enum.StrEnum):
    user = "user"
    content = "content"
    friend_relationship = "friend_relationship"
    auth = "auth"
    message_access_denial = "message_access_denial"


class AdminActionOutcome(enum.StrEnum):
    success = "success"
    denied = "denied"
    failed = "failed"


class AdminAction(Base):
    __tablename__ = "admin_actions"

    occurred_at: Mapped[datetime] = mapped_column(nullable=False)
    actor_admin_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), nullable=False)
    entity_type: Mapped[AdminEntityType] = mapped_column(nullable=False)
    entity_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), nullable=True)
    operation_name: Mapped[str] = mapped_column(String(100), nullable=False)
    outcome: Mapped[AdminActionOutcome] = mapped_column(nullable=False)
    change_payload: Mapped[dict] = mapped_column(JSONB, nullable=False, default=dict)

    __table_args__ = (
        Index("ix_admin_actions_actor_admin_id", "actor_admin_id"),
        Index("ix_admin_actions_entity", "entity_type", "entity_id"),
        Index("ix_admin_actions_occurred_at", "occurred_at"),
    )
