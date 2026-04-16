import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.infrastructure.persistence.models.friend import FriendStatus
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.friend_repository import (
    SqlAlchemyFriendRepository,
)

router = APIRouter(prefix="/friends", tags=["friends"])


class FriendStatusResponse(BaseModel):
    target_user_id: uuid.UUID
    status: str
    is_following: bool


class IncomingFollowRequestResponse(BaseModel):
    requester_user_id: uuid.UUID
    requester_username: str
    requested_at: datetime


class FriendSummaryResponse(BaseModel):
    user_id: uuid.UUID
    username: str
    avatar_url: str | None


def _avatar_url(user_id: uuid.UUID, avatar_path: str | None) -> str | None:
    if not avatar_path:
        return None
    return f"/v1/users/{user_id}/avatar"


@router.get("/requests/incoming", response_model=list[IncomingFollowRequestResponse])
async def list_incoming_follow_requests(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    repo = SqlAlchemyFriendRepository(db)
    requests = await repo.list_incoming_follow_requests(current_user.id)
    return [
        IncomingFollowRequestResponse(
            requester_user_id=requester_id,
            requester_username=username,
            requested_at=requested_at,
        )
        for requester_id, username, requested_at in requests
    ]


@router.get("", response_model=list[FriendSummaryResponse])
async def list_friends(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    repo = SqlAlchemyFriendRepository(db)
    friends = await repo.list_accepted_friends(current_user.id)
    return [
        FriendSummaryResponse(
            user_id=friend_id,
            username=username,
            avatar_url=_avatar_url(friend_id, avatar_path),
        )
        for friend_id, username, avatar_path in friends
    ]


@router.get("/followers", response_model=list[FriendSummaryResponse])
async def list_followers(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    repo = SqlAlchemyFriendRepository(db)
    followers = await repo.list_followers(current_user.id)
    return [
        FriendSummaryResponse(
            user_id=user_id,
            username=username,
            avatar_url=_avatar_url(user_id, avatar_path),
        )
        for user_id, username, avatar_path in followers
    ]


@router.get("/following", response_model=list[FriendSummaryResponse])
async def list_following(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    repo = SqlAlchemyFriendRepository(db)
    following = await repo.list_following(current_user.id)
    return [
        FriendSummaryResponse(
            user_id=user_id,
            username=username,
            avatar_url=_avatar_url(user_id, avatar_path),
        )
        for user_id, username, avatar_path in following
    ]


@router.get("/{userId}/status", response_model=FriendStatusResponse)
async def get_friend_status(
    userId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    if userId == current_user.id:
        return FriendStatusResponse(
            target_user_id=userId,
            status="self",
            is_following=False,
        )

    target_user = (await db.execute(select(User).where(User.id == userId))).scalar_one_or_none()
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    repo = SqlAlchemyFriendRepository(db)
    status = await repo.get_relationship_status(current_user.id, userId)
    return FriendStatusResponse(
        target_user_id=userId,
        status=status,
        is_following=status == "accepted",
    )


@router.post("/{userId}/request", response_model=FriendStatusResponse)
async def request_follow(
    userId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    target_user = (await db.execute(select(User).where(User.id == userId))).scalar_one_or_none()
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    repo = SqlAlchemyFriendRepository(db)
    try:
        relationship = await repo.send_follow_request(current_user.id, userId)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    status = await repo.get_relationship_status(current_user.id, userId)
    return FriendStatusResponse(
        target_user_id=userId,
        status=status,
        is_following=relationship.status == FriendStatus.accepted,
    )


@router.post("/{userId}/accept", response_model=FriendStatusResponse)
async def accept_follow(
    userId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    target_user = (await db.execute(select(User).where(User.id == userId))).scalar_one_or_none()
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    repo = SqlAlchemyFriendRepository(db)
    try:
        relationship = await repo.accept_follow_request(current_user.id, userId)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    status = await repo.get_relationship_status(current_user.id, userId)
    return FriendStatusResponse(
        target_user_id=userId,
        status=status,
        is_following=relationship.status == FriendStatus.accepted,
    )
