"""Admin friend relationship endpoints."""

import uuid

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.application.use_cases.admin_friend_relationships import AdminFriendRelationshipsUseCases
from backend.core.admin_deps import get_current_admin
from backend.core.database import get_db_session
from backend.infrastructure.persistence.models.admin import AdminAccount
from backend.infrastructure.persistence.repositories.admin_action_repository import (
    AdminActionRepository,
)
from backend.infrastructure.persistence.repositories.admin_friend_relationships_repository import (
    AdminFriendRelationshipsRepository,
)

router = APIRouter(prefix="/friend-relationships", tags=["admin-relationships"])


class RelationshipActionRequest(BaseModel):
    action_type: str
    reason: str
    confirmed: bool = False


def _get_use_cases(db: AsyncSession = Depends(get_db_session)) -> AdminFriendRelationshipsUseCases:
    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)
    return AdminFriendRelationshipsUseCases(
        relationship_repo=AdminFriendRelationshipsRepository(db),
        audit=audit,
    )


@router.get("")
async def list_relationships(
    page: int = Query(1, ge=1),
    page_size: int = Query(20, ge=1, le=100),
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminFriendRelationshipsUseCases = Depends(_get_use_cases),
) -> dict:
    items = await use_cases.list_relationships(page=page, page_size=page_size)
    return {"items": items, "page": page, "page_size": page_size}


@router.get("/{relationship_id}")
async def get_relationship(
    relationship_id: uuid.UUID,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminFriendRelationshipsUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        return await use_cases.get_relationship(relationship_id)
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.post("/{relationship_id}/actions")
async def apply_relationship_action(
    relationship_id: uuid.UUID,
    body: RelationshipActionRequest,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminFriendRelationshipsUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        result = await use_cases.apply_action(
            relationship_id=relationship_id,
            actor_admin_id=admin.id,
            action_type=body.action_type,
            reason=body.reason,
            confirmed=body.confirmed,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return {
        "outcome": "success",
        "message": f"Action '{body.action_type}' applied",
        "admin_action_id": None,
        "relationship": result,
    }


@router.delete("/{relationship_id}")
async def delete_relationship_permanently(
    relationship_id: uuid.UUID,
    admin: AdminAccount = Depends(get_current_admin),
    use_cases: AdminFriendRelationshipsUseCases = Depends(_get_use_cases),
) -> dict:
    try:
        await use_cases.delete_permanently(
            relationship_id=relationship_id,
            actor_admin_id=admin.id,
            reason="Permanent deletion via admin API",
        )
    except ValueError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc

    return {"outcome": "success", "message": "Relationship permanently deleted"}
