import enum

from sqlalchemy import Boolean, Index, String
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class AdminPermissionScope(enum.StrEnum):
    full_admin = "full_admin"


class AdminAccount(TimestampMixin, Base):
    __tablename__ = "admin_accounts"

    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    password_hash: Mapped[str] = mapped_column(String(255), nullable=False)
    display_name: Mapped[str] = mapped_column(String(100), nullable=False)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    permission_scope: Mapped[AdminPermissionScope] = mapped_column(nullable=False, default=AdminPermissionScope.full_admin)

    __table_args__ = (
        Index("ix_admin_accounts_email", "email"),
        Index("ix_admin_accounts_is_active", "is_active"),
    )
