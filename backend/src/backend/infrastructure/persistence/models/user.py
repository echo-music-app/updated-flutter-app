import enum
from datetime import datetime

from sqlalchemy import ARRAY, Boolean, Index, LargeBinary, String, Text
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class UserStatus(enum.StrEnum):
    pending = "pending"
    active = "active"
    disabled = "disabled"
    suspended = "suspended"


class User(TimestampMixin, Base):
    __tablename__ = "users"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    username: Mapped[str] = mapped_column(String(50), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    apple_subject: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    soundcloud_subject: Mapped[str | None] = mapped_column(String(255), unique=True, nullable=True)
    email_verified_at: Mapped[datetime | None] = mapped_column(nullable=True)
    email_verification_code_hash: Mapped[bytes | None] = mapped_column(LargeBinary(32), nullable=True)
    email_verification_expires_at: Mapped[datetime | None] = mapped_column(nullable=True)
    email_verification_sent_at: Mapped[datetime | None] = mapped_column(nullable=True)
    mfa_enabled: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False, server_default="false")
    mfa_totp_secret: Mapped[str | None] = mapped_column(String(128), nullable=True)
    avatar_path: Mapped[str | None] = mapped_column(String(512), nullable=True)
    bio: Mapped[str | None] = mapped_column(String(200), nullable=True)
    preferred_genres: Mapped[list[str]] = mapped_column(ARRAY(Text), nullable=False, server_default="{}")
    status: Mapped[UserStatus] = mapped_column(nullable=False, default=UserStatus.pending)
    is_artist: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)

    __table_args__ = (
        Index("ix_users_email", "email"),
        Index("ix_users_apple_subject", "apple_subject"),
        Index("ix_users_soundcloud_subject", "soundcloud_subject"),
        Index("ix_users_username", "username"),
        Index("ix_users_status", "status"),
    )


class AdminUser(Base):
    __tablename__ = "admin_users"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[str] = mapped_column(server_default="now()")
