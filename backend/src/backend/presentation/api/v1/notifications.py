import uuid
from datetime import datetime

from fastapi import APIRouter, Depends
from pydantic import BaseModel
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.post_repository import SqlAlchemyPostRepository

router = APIRouter(prefix="/notifications", tags=["notifications"])


class PostActivityNotificationResponse(BaseModel):
    id: uuid.UUID
    actor_user_id: uuid.UUID
    actor_username: str
    post_id: uuid.UUID
    activity_type: str
    comment_preview: str | None
    created_at: datetime


@router.get("/post-activity", response_model=list[PostActivityNotificationResponse])
async def list_post_activity_notifications(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    repo = SqlAlchemyPostRepository(db)
    rows = await repo.list_activity_notifications(recipient_user_id=current_user.id)
    return [
        PostActivityNotificationResponse(
            id=notification.id,
            actor_user_id=notification.actor_user_id,
            actor_username=actor_username,
            post_id=notification.post_id,
            activity_type=str(
                notification.activity_type.value
                if hasattr(notification.activity_type, "value")
                else notification.activity_type
            ),
            comment_preview=notification.comment_preview,
            created_at=notification.created_at,
        )
        for notification, actor_username in rows
    ]
