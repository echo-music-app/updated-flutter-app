"""Admin content moderation use cases."""

import uuid
from typing import Any

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)

_VALID_ACTIONS = {"remove", "restore", "delete_permanently"}


class AdminContentUseCases:
    def __init__(
        self,
        content_repo: Any,
        audit: AdminAuditUseCase,
    ) -> None:
        self._content_repo = content_repo
        self._audit = audit

    async def list_content(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        query: str | None = None,
        status: list[str] | None = None,
    ) -> list[dict]:
        return await self._content_repo.list_managed(page=page, page_size=page_size, query=query, status=status)

    async def get_content(self, content_id: uuid.UUID) -> dict:
        return await self._content_repo.get_managed(content_id)

    async def apply_content_action(
        self,
        *,
        content_id: uuid.UUID,
        actor_admin_id: uuid.UUID,
        action_type: str,
        reason: str,
        confirmed: bool,
    ) -> dict:
        if action_type not in _VALID_ACTIONS:
            raise ValueError(f"Unknown action_type: {action_type}")

        if action_type == "delete_permanently" and not confirmed:
            raise ValueError("Permanent deletion requires explicit confirmation")

        await self._content_repo.get_managed(content_id)
        result = await self._content_repo.apply_action(content_id, action_type)

        await self._audit.record(
            actor_admin_id=actor_admin_id,
            entity_type=AdminEntityType.content,
            entity_id=content_id,
            operation_name=f"content_{action_type}",
            outcome=AdminActionOutcome.success,
            change_payload={"action_type": action_type, "reason": reason},
        )

        return result

    async def delete_permanently(
        self,
        *,
        content_id: uuid.UUID,
        actor_admin_id: uuid.UUID,
        reason: str,
    ) -> None:
        await self._content_repo.delete_permanently(content_id)

        await self._audit.record(
            actor_admin_id=actor_admin_id,
            entity_type=AdminEntityType.content,
            entity_id=content_id,
            operation_name="content_delete_permanently",
            outcome=AdminActionOutcome.success,
            change_payload={"reason": reason},
        )
