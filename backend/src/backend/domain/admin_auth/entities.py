"""Admin auth domain entities."""

import uuid
from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum


class AdminStatus(StrEnum):
    active = "active"
    disabled = "disabled"


class AdminPermissionScope(StrEnum):
    full_admin = "full_admin"


@dataclass(frozen=True)
class AdminSessionInfo:
    """Represents a successfully authenticated admin session."""

    admin_id: uuid.UUID
    email: str
    display_name: str
    status: AdminStatus
    permission_scope: AdminPermissionScope
    authenticated_at: datetime
    access_token: str
