"""Admin audit use case.

Records an AdminAction for every /admin/v1 operation outcome — successful,
explicitly denied (message boundary), and authorization failures.
Non-mutating and denied operations use an empty change_payload.
"""

import uuid

from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)
from backend.infrastructure.persistence.repositories.admin_action_repository import (
    AdminActionRepository,
)


class AdminAuditUseCase:
    def __init__(self, action_repo: AdminActionRepository) -> None:
        self._action_repo = action_repo

    async def record(
        self,
        *,
        actor_admin_id: uuid.UUID,
        entity_type: AdminEntityType,
        entity_id: uuid.UUID | None,
        operation_name: str,
        outcome: AdminActionOutcome,
        change_payload: dict,
    ) -> None:
        """Persist a single immutable AdminAction record for an admin operation."""
        await self._action_repo.create(
            actor_admin_id=actor_admin_id,
            entity_type=entity_type,
            entity_id=entity_id,
            operation_name=operation_name,
            outcome=outcome,
            change_payload=change_payload,
        )
