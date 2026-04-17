import enum
import uuid
from datetime import datetime

from sqlalchemy import ForeignKey, Index, String, Text, UniqueConstraint
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class PostActivityType(enum.StrEnum):
    like = "like"
    comment = "comment"


class PostLike(TimestampMixin, Base):
    __tablename__ = "post_likes"

    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)

    __table_args__ = (
        UniqueConstraint("post_id", "user_id", name="uq_post_likes_post_user"),
        Index("ix_post_likes_post_id", "post_id"),
        Index("ix_post_likes_user_id", "user_id"),
    )


class PostComment(TimestampMixin, Base):
    __tablename__ = "post_comments"

    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)

    __table_args__ = (
        Index("ix_post_comments_post_id", "post_id"),
        Index("ix_post_comments_user_id", "user_id"),
    )


class PostActivityNotification(TimestampMixin, Base):
    __tablename__ = "post_activity_notifications"

    recipient_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
    )
    post_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=False)
    activity_type: Mapped[PostActivityType] = mapped_column(nullable=False)
    comment_preview: Mapped[str | None] = mapped_column(String(200), nullable=True)
    read_at: Mapped[datetime | None] = mapped_column(nullable=True)

    __table_args__ = (
        Index("ix_post_activity_notifications_recipient_user_id", "recipient_user_id"),
        Index("ix_post_activity_notifications_post_id", "post_id"),
    )
