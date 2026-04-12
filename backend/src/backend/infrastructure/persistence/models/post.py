import enum
import uuid

from sqlalchemy import ForeignKey
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base, TimestampMixin


class Privacy(enum.StrEnum):
    public = "Public"
    friends = "Friends"
    only_me = "OnlyMe"


class Post(TimestampMixin, Base):
    __tablename__ = "posts"

    user_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    privacy: Mapped[Privacy] = mapped_column(nullable=False)
