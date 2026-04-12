"""Admin friend relationship use cases."""

import uuid
from typing import Any

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)

_VALID_ACTIONS = {"remove", "restore", "delete_permanently"}


class AdminFriendRelationshipsUseCases:
    def __init__(
        self,
        relationship_repo: Any,
        audit: AdminAuditUseCase,
    ) -> None:
        self._relationship_repo = relationship_repo
        self._audit = audit

    async def list_relationships(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
    ) -> list[dict]:
        return await self._relationship_repo.list_managed(page=page, page_size=page_size)

    async def get_relationship(self, relationship_id: uuid.UUID) -> dict:
        return await self._relationship_repo.get_managed(relationship_id)

    async def apply_action(
        self,
        *,
        relationship_id: uuid.UUID,
        actor_admin_id: uuid.UUID,
        action_type: str,
        reason: str,
        confirmed: bool,
    ) -> dict:
        if action_type not in _VALID_ACTIONS:
            raise ValueError(f"Unknown action_type: {action_type}")

        if action_type == "delete_permanently" and not confirmed:
            raise ValueError("Permanent deletion requires explicit confirmation")

        result = await self._relationship_repo.apply_action(relationship_id, action_type)

        await self._audit.record(
            actor_admin_id=actor_admin_id,
            entity_type=AdminEntityType.friend_relationship,
            entity_id=relationship_id,
            operation_name=f"relationship_{action_type}",
            outcome=AdminActionOutcome.success,
            change_payload={"action_type": action_type, "reason": reason},
        )

        return result

    async def delete_permanently(
        self,
        *,
        relationship_id: uuid.UUID,
        actor_admin_id: uuid.UUID,
        reason: str,
    ) -> None:
        await self._relationship_repo.delete_permanently(relationship_id)

        await self._audit.record(
            actor_admin_id=actor_admin_id,
            entity_type=AdminEntityType.friend_relationship,
            entity_id=relationship_id,
            operation_name="relationship_delete_permanently",
            outcome=AdminActionOutcome.success,
            change_payload={"reason": reason},
        )
