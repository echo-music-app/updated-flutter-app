import enum
import uuid
from datetime import datetime

from sqlalchemy import BigInteger, CheckConstraint, ForeignKey, String, Text, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from backend.infrastructure.persistence.models.base import Base


class AttachmentType(enum.StrEnum):
    text = "text"
    artist_post = "artist_post"
    spotify_link = "spotify_link"
    soundcloud_link = "soundcloud_link"
    audio_file = "audio_file"
    video_file = "video_file"


class AttachmentUrlProvider(enum.StrEnum):
    nginx_secure_link = "nginx_secure_link"
    cloudfront = "cloudfront"


class Attachment(Base):
    __tablename__ = "attachments"

    attachment_type: Mapped[AttachmentType] = mapped_column(nullable=False)
    post_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("posts.id", ondelete="CASCADE"), nullable=True)
    message_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True), ForeignKey("messages.id", ondelete="CASCADE"), nullable=True)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
    content: Mapped[str | None] = mapped_column(Text, nullable=True)
    url: Mapped[str | None] = mapped_column(String(512), nullable=True)
    track_id: Mapped[str | None] = mapped_column(String(64), nullable=True)
    storage_key: Mapped[str | None] = mapped_column(String(512), nullable=True)
    mime_type: Mapped[str | None] = mapped_column(String(64), nullable=True)
    size_bytes: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    url_provider_override: Mapped[AttachmentUrlProvider | None] = mapped_column(nullable=True)

    __mapper_args__ = {"polymorphic_on": attachment_type, "polymorphic_identity": None}

    __table_args__ = (CheckConstraint("post_id IS NOT NULL OR message_id IS NOT NULL", name="ck_attachments_parent"),)


class AttachmentText(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.text}


class AttachmentArtistPost(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.artist_post}


class AttachmentSpotifyLink(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.spotify_link}


class AttachmentSoundCloudLink(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.soundcloud_link}


class AttachmentAudioFile(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.audio_file}


class AttachmentVideoFile(Attachment):
    __mapper_args__ = {"polymorphic_identity": AttachmentType.video_file}
