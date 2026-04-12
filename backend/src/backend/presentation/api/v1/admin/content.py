"""Admin content moderation endpoints."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.application.use_cases.admin_content import AdminContentUseCases
from backend.core.admin_deps import get_current_admin
from backend.core.database import get_db_session
from backend.infrastructure.persistence.models.admin import AdminAccount
from backend.infrastructure.persistence.repositories.admin_action_repository import (
    AdminActionRepository,
)
from backend.infrastructure.persistence.repositories.admin_content_repository import (
    AdminContentRepository,
)

router = APIRouter(prefix="/content", tags=["admin-content"])


class ContentActionRequest(BaseModel):
    action_type: str
    reason: str
    confirmed: bool = False


def _get_use_cases(db: AsyncSession = Depends(get_db_session)) -> AdminContentUseCases:
    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)
    return AdminContentUseCases(content_repo=AdminContentRepository(db), audit=audit)


@router.get("")
async def list_content(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminContentUseCases = Depends(_get_use_cases),
) -> dict:
    items = await use_cases.list_content(page=page, page_size=page_size)
    return {"items": items, "page": page, "page_size": page_size}


@router.get("/{content_id}")
async def get_content(
    content_id: uuid.UUID,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminContentUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        return await use_cases.get_content(content_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/{content_id}/actions")
async def apply_content_action(
    content_id: uuid.UUID,
    body: ContentActionRequest,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminContentUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        result = await use_cases.apply_content_action(
            content_id=content_id,
            actor_admin_id=admin.id,
            action_type=body.action_type,
            reason=body.reason,
            confirmed=body.confirmed,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return {
        "outcome": "success",
        "message": f"Content action '{body.action_type}' applied",
        "admin_action_id": None,
        "content": result,
    }


@router.delete("/{content_id}")
async def delete_content_permanently(
    content_id: uuid.UUID,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminContentUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        await use_cases.delete_permanently(
            content_id=content_id,
            actor_admin_id=admin.id,
            reason="Permanent deletion via admin API",
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return {"outcome": "success", "message": "Content permanently deleted"}
