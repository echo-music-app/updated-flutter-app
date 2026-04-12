"""Admin authentication token persistence model."""

import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, LargeBinary
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base


class AdminAccessToken(Base):
    __tablename__ = "admin_access_tokens"

    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), unique=True, nullable=False)
    admin_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("admin_accounts.id", ondelete="CASCADE"),
        nullable=False,
    )
    expires_at: Mapped[datetime] = mapped_column(nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(nullable=False)

    __table_args__ = (
        Index("ix_admin_access_tokens_admin_id", "admin_id"),
        Index(
            "ix_admin_access_tokens_active",
            "expires_at",
            postgresql_where="revoked_at IS NULL",
        ),
    )
