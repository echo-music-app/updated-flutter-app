import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, LargeBinary, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class SpotifyCredentials(TimestampMixin, Base):
    __tablename__ = "spotify_credentials"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), unique=True, nullable=False)
    access_token: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    refresh_token: Mapped[bytes] = mapped_column(LargeBinary, nullable=False)
    token_expiry: Mapped[datetime] = mapped_column(nullable=False)
    spotify_user_id: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    scope: Mapped[str] = mapped_column(Text, nullable=False)

    __table_args__ = (
        Index("ix_spotify_credentials_user_id", "user_id"),
        Index("ix_spotify_credentials_spotify_user_id", "spotify_user_id"),
    )
