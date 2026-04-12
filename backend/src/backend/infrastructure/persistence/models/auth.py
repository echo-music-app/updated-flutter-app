import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, LargeBinary, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base


class AccessToken(Base):
    __tablename__ = "access_tokens"

    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), unique=True, nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    expires_at: Mapped[datetime] = mapped_column(nullable=False)
    revoked_at: Mapped[datetime | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    __table_args__ = (
        Index("ix_access_tokens_user_id", "user_id"),
        Index("ix_access_tokens_active", "expires_at", postgresql_where="revoked_at IS NULL"),
    )


class RefreshToken(Base):
    __tablename__ = "refresh_tokens"

    token_hash: Mapped[bytes] = mapped_column(LargeBinary(32), unique=True, nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    access_token_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("access_tokens.id", ondelete="SET NULL"), nullable=True
    )
    expires_at: Mapped[datetime] = mapped_column(nullable=False)
    rotated_at: Mapped[datetime | None] = mapped_column(nullable=True)
    revoked_at: Mapped[datetime | None] = mapped_column(nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())

    __table_args__ = (Index("ix_refresh_tokens_user_id", "user_id"),)
