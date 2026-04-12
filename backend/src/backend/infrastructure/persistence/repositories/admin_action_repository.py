import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.admin_action import (
    AdminAction,
    AdminActionOutcome,
    AdminEntityType,
)


class AdminActionRepository:
    def __init__(self, db: AsyncSession) -> None:
        self._db = db

    async def create(
        self,
        *,
        actor_admin_id: uuid.UUID,
        entity_type: AdminEntityType,
        entity_id: uuid.UUID | None,
        operation_name: str,
        outcome: AdminActionOutcome,
        change_payload: dict,
    ) -> AdminAction:
        action = AdminAction(
            occurred_at=datetime.now(UTC),
            actor_admin_id=actor_admin_id,
            entity_type=entity_type,
            entity_id=entity_id,
            operation_name=operation_name,
            outcome=outcome,
            change_payload=change_payload,
        )
        self._db.add(action)
        await self._db.flush()
        await self._db.refresh(action)
        return action

    async def list_by_entity(
        self,
        entity_type: AdminEntityType,
        entity_id: uuid.UUID,
        *,
        limit: int = 50,
    ) -> Sequence[AdminAction]:
        result = await self._db.execute(
            select(AdminAction)
            .where(
                AdminAction.entity_type == entity_type,
                AdminAction.entity_id == entity_id,
            )
            .order_by(AdminAction.occurred_at.desc())
            .limit(limit)
        )
        return result.scalars().all()

    async def list_by_actor(
        self,
        actor_admin_id: uuid.UUID,
        *,
        limit: int = 50,
    ) -> Sequence[AdminAction]:
        result = await self._db.execute(
            select(AdminAction).where(AdminAction.actor_admin_id == actor_admin_id).order_by(AdminAction.occurred_at.desc()).limit(limit)
        )
        return result.scalars().all()
