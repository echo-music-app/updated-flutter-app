"""Admin friend relationship moderation repository."""

import uuid

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.friend import Friend, FriendStatus


class AdminFriendRelationshipsRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    def _to_projection(self, friend: Friend) -> dict:
        return {
            "id": str(friend.id),
            "user_a_id": str(friend.user1_id),
            "user_b_id": str(friend.user2_id),
            "status": friend.status.value,
            "created_at": friend.created_at.isoformat() if friend.created_at else None,
            "updated_at": friend.updated_at.isoformat() if friend.updated_at else None,
        }

    async def list_managed(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
    ) -> list[dict]:
        stmt = select(Friend).offset((page - 1) * page_size).limit(page_size)
        result = await self._db.execute(stmt)
        return [self._to_projection(f) for f in result.scalars().all()]

    async def get_managed(self, relationship_id: uuid.UUID) -> dict:
        result = await self._db.execute(select(Friend).where(Friend.id == relationship_id))
        friend = result.scalar_one_or_none()
        if friend is None:
            raise ValueError(f"Relationship {relationship_id} not found")
        return self._to_projection(friend)

    async def apply_action(self, relationship_id: uuid.UUID, action_type: str) -> dict:
        result = await self._db.execute(select(Friend).where(Friend.id == relationship_id))
        friend = result.scalar_one_or_none()
        if friend is None:
            raise ValueError(f"Relationship {relationship_id} not found")

        if action_type == "remove":
            friend.status = FriendStatus.declined
        elif action_type == "restore":
            friend.status = FriendStatus.accepted
        await self._db.flush()
        await self._db.refresh(friend)
        return self._to_projection(friend)

    async def delete_permanently(self, relationship_id: uuid.UUID) -> None:
        result = await self._db.execute(select(Friend).where(Friend.id == relationship_id))
        friend = result.scalar_one_or_none()
        if friend is not None:
            await self._db.delete(friend)
            await self._db.flush()
