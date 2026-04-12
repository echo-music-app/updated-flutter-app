# Import all models so SQLAlchemy can resolve foreign key references across modules
from backend.infrastructure.persistence.models.admin import AdminAccount, AdminPermissionScope  # noqa: F401
from backend.infrastructure.persistence.models.admin_action import AdminAction, AdminActionOutcome, AdminEntityType  # noqa: F401
from backend.infrastructure.persistence.models.admin_auth import AdminAccessToken  # noqa: F401
from backend.infrastructure.persistence.models.attachment import (  # noqa: F401
    Attachment,
    AttachmentArtistPost,
    AttachmentAudioFile,
    AttachmentSoundCloudLink,
    AttachmentSpotifyLink,
    AttachmentText,
    AttachmentType,
    AttachmentUrlProvider,
    AttachmentVideoFile,
)
from backend.infrastructure.persistence.models.auth import AccessToken, RefreshToken  # noqa: F401
from backend.infrastructure.persistence.models.base import Base, TimestampMixin  # noqa: F401
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus  # noqa: F401
from backend.infrastructure.persistence.models.message import Message, MessageThread, MessageThreadParticipant  # noqa: F401
from backend.infrastructure.persistence.models.post import Post, Privacy  # noqa: F401
from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials  # noqa: F401
from backend.infrastructure.persistence.models.user import User, UserStatus  # noqa: F401
