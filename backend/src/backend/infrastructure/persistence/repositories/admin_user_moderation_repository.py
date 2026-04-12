"""Admin user moderation repository.

Returns managed admin-facing projections over User records.
Sensitive fields (email) are anonymized before serialization.
"""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.user import User, UserStatus


def _anonymize_email(email: str) -> str:
    """Mask email — show domain only: ***@example.com"""
    parts = email.split("@", 1)
    if len(parts) == 2:
        return f"***@{parts[1]}"
    return "***"


class AdminUserModerationRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    def _to_summary(self, user: User) -> dict:
        return {
            "id": str(user.id),
            "username": user.username,
            "email": _anonymize_email(user.email),
            "status": user.status.value,
            "created_at": user.created_at.isoformat() if hasattr(user, "created_at") else None,
            "flag_count": 0,
        }

    async def list_managed(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        query: str | None = None,
        status: list[str] | None = None,
    ) -> list[dict]:
        stmt = select(User).offset((page - 1) * page_size).limit(page_size)
        if status:
            stmt = stmt.where(User.status.in_(status))
        result = await self._db.execute(stmt)
        return [self._to_summary(u) for u in result.scalars().all()]

    async def get_managed(self, user_id: uuid.UUID) -> dict:
        result = await self._db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ValueError(f"User {user_id} not found")
        return self._to_summary(user)

    async def update_status(self, user_id: uuid.UUID, new_status: str) -> dict:
        result = await self._db.execute(select(User).where(User.id == user_id))
        user = result.scalar_one_or_none()
        if user is None:
            raise ValueError(f"User {user_id} not found")
        user.status = UserStatus(new_status)
        await self._db.flush()
        return self._to_summary(user)
