"""Admin user moderation use cases."""

import uuid
from typing import Any

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)

_VALID_USER_STATUSES = {"active", "disabled", "pending", "suspended"}
_READONLY_FIELD_MASK = {"email"}  # anonymized before serialization


class AdminUsersUseCases:
    def __init__(
        self,
        user_repo: Any,
        audit: AdminAuditUseCase,
    ) -> None:
        self._user_repo = user_repo
        self._audit = audit

    async def list_users(
        self,
        *,
        page: int = 1,
        page_size: int = 20,
        query: str | None = None,
        status: list[str] | None = None,
    ) -> list[dict]:
        return await self._user_repo.list_managed(page=page, page_size=page_size, query=query, status=status)

    async def get_user(self, user_id: uuid.UUID) -> dict:
        return await self._user_repo.get_managed(user_id)

    async def change_user_status(
        self,
        *,
        user_id: uuid.UUID,
        actor_admin_id: uuid.UUID,
        new_status: str,
        reason: str,
    ) -> dict:
        if new_status not in _VALID_USER_STATUSES:
            raise ValueError(f"Status '{new_status}' is invalid. Allowed values: {sorted(_VALID_USER_STATUSES)}.")

        current = await self._user_repo.get_managed(user_id)
        old_status = current.get("status") if isinstance(current, dict) else getattr(current, "status", None)

        result = await self._user_repo.update_status(user_id, new_status)

        await self._audit.record(
            actor_admin_id=actor_admin_id,
            entity_type=AdminEntityType.user,
            entity_id=user_id,
            operation_name="user_status_change",
            outcome=AdminActionOutcome.success,
            change_payload={
                "status_before": str(old_status),
                "status_after": new_status,
                "reason": reason,
            },
        )

        return result
