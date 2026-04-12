import enum
import uuid

from sqlalchemy import CheckConstraint, ForeignKey, Index, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class FriendStatus(enum.StrEnum):
    pending = "pending"
    accepted = "accepted"
    declined = "declined"


class Friend(TimestampMixin, Base):
    __tablename__ = "friends"

    user1_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    user2_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    status: Mapped[FriendStatus] = mapped_column(nullable=False, default=FriendStatus.pending)

    __table_args__ = (
        CheckConstraint("user1_id < user2_id", name="ck_friends_ordered"),
        UniqueConstraint("user1_id", "user2_id", name="uq_friends_user_pair"),
        Index("ix_friends_user1_id", "user1_id"),
        Index("ix_friends_user2_id", "user2_id"),
    )
