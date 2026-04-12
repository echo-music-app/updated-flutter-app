"""Admin user management endpoints."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.application.use_cases.admin_users import AdminUsersUseCases
from backend.core.admin_deps import get_current_admin
from backend.core.database import get_db_session
from backend.infrastructure.persistence.models.admin import AdminAccount
from backend.infrastructure.persistence.repositories.admin_action_repository import (
    AdminActionRepository,
)
from backend.infrastructure.persistence.repositories.admin_user_moderation_repository import (
    AdminUserModerationRepository,
)

router = APIRouter(prefix="/users", tags=["admin-users"])


class UserStatusUpdateRequest(BaseModel):
    status: str
    reason: str


def _get_use_cases(db: AsyncSession = Depends(get_db_session)) -> AdminUsersUseCases:
    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)
    return AdminUsersUseCases(
        user_repo=AdminUserModerationRepository(db),
        audit=audit,
    )


@router.get("")
async def list_users(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    query: str | None = Query(None),
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminUsersUseCases = Depends(_get_use_cases),
) -> dict:
    items = await use_cases.list_users(page=page, page_size=page_size, query=query)
    return {"items": items, "page": page, "page_size": page_size}


@router.get("/{user_id}")
async def get_user(
    user_id: uuid.UUID,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminUsersUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        return await use_cases.get_user(user_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.patch("/{user_id}/status")
async def update_user_status(
    user_id: uuid.UUID,
    body: UserStatusUpdateRequest,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminUsersUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        result = await use_cases.change_user_status(
            user_id=user_id,
            actor_admin_id=admin.id,
            new_status=body.status,
            reason=body.reason,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return {
        "outcome": "success",
        "message": f"User status updated to {body.status}",
        "admin_action_id": None,
        "user": result,
    }
