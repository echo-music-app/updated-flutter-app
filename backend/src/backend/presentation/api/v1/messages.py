import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field
from sqlalchemy import desc, distinct, func, select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.infrastructure.persistence.models.attachment import (
    Attachment,
    AttachmentText,
    AttachmentType,
)
from backend.infrastructure.persistence.models.message import (
    Message,
    MessageThread,
    MessageThreadParticipant,
)
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.friend_repository import (
    SqlAlchemyFriendRepository,
)

router = APIRouter(prefix="/messages", tags=["messages"])


class MessageThreadSummaryResponse(BaseModel):
    user_id: uuid.UUID
    username: str
    last_message_preview: str
    last_message_at: datetime


class DirectMessageItemResponse(BaseModel):
    id: uuid.UUID
    sender_user_id: uuid.UUID
    sender_username: str
    text: str
    created_at: datetime
    is_mine: bool


class DirectMessageThreadResponse(BaseModel):
    target_user_id: uuid.UUID
    target_username: str
    items: list[DirectMessageItemResponse]


class SendDirectMessageRequest(BaseModel):
    text: str = Field(min_length=1, max_length=1000)


async def _ensure_target_user_exists(db: AsyncSession, user_id: uuid.UUID) -> User:
    target_user = (await db.execute(select(User).where(User.id == user_id))).scalar_one_or_none()
    if target_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return target_user


async def _ensure_friendship(
    db: AsyncSession,
    current_user_id: uuid.UUID,
    target_user_id: uuid.UUID,
) -> None:
    relationship_status = await SqlAlchemyFriendRepository(db).get_relationship_status(
        current_user_id,
        target_user_id,
    )
    if relationship_status != "accepted":
        raise HTTPException(
            status_code=403,
            detail="Messaging is only available between friends",
        )


async def _find_direct_thread_id(
    db: AsyncSession,
    user_a: uuid.UUID,
    user_b: uuid.UUID,
) -> uuid.UUID | None:
    stmt = (
        select(MessageThreadParticipant.thread_id)
        .where(MessageThreadParticipant.user_id.in_([user_a, user_b]))
        .group_by(MessageThreadParticipant.thread_id)
        .having(func.count(distinct(MessageThreadParticipant.user_id)) == 2)
    )
    rows = (await db.execute(stmt)).scalars().all()
    if not rows:
        return None
    return rows[0]


async def _create_direct_thread(
    db: AsyncSession,
    user_a: uuid.UUID,
    user_b: uuid.UUID,
) -> uuid.UUID:
    thread = MessageThread()
    db.add(thread)
    await db.flush()

    db.add(
        MessageThreadParticipant(thread_id=thread.id, user_id=user_a),
    )
    db.add(
        MessageThreadParticipant(thread_id=thread.id, user_id=user_b),
    )
    await db.flush()
    return thread.id


async def _load_thread_messages(
    db: AsyncSession,
    thread_id: uuid.UUID,
    current_user_id: uuid.UUID,
) -> list[DirectMessageItemResponse]:
    message_rows = (
        await db.execute(
            select(Message, User.username)
            .join(User, User.id == Message.sender_id)
            .where(Message.thread_id == thread_id)
            .order_by(Message.created_at.asc())
            .limit(200)
        )
    ).all()
    if not message_rows:
        return []

    message_ids = [message.id for message, _ in message_rows]
    attachments = (
        await db.execute(
            select(Attachment.message_id, Attachment.content).where(
                Attachment.message_id.in_(message_ids),
                Attachment.attachment_type == AttachmentType.text,
            )
        )
    ).all()
    text_by_message_id: dict[uuid.UUID, str] = {
        message_id: content or ""
        for message_id, content in attachments
        if message_id is not None
    }

    return [
        DirectMessageItemResponse(
            id=message.id,
            sender_user_id=message.sender_id,
            sender_username=sender_username,
            text=text_by_message_id.get(message.id, ""),
            created_at=message.created_at,
            is_mine=message.sender_id == current_user_id,
        )
        for message, sender_username in message_rows
    ]


@router.get("/threads", response_model=list[MessageThreadSummaryResponse])
async def list_message_threads(
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    thread_ids = (
        await db.execute(
            select(MessageThreadParticipant.thread_id).where(
                MessageThreadParticipant.user_id == current_user.id,
            )
        )
    ).scalars().all()
    if not thread_ids:
        return []

    other_participants = (
        await db.execute(
            select(
                MessageThreadParticipant.thread_id,
                MessageThreadParticipant.user_id,
            ).where(
                MessageThreadParticipant.thread_id.in_(thread_ids),
                MessageThreadParticipant.user_id != current_user.id,
            )
        )
    ).all()
    if not other_participants:
        return []

    other_user_by_thread: dict[uuid.UUID, uuid.UUID] = {
        thread_id: user_id for thread_id, user_id in other_participants
    }
    other_user_ids = list({user_id for _, user_id in other_participants})

    user_rows = (
        await db.execute(select(User.id, User.username).where(User.id.in_(other_user_ids)))
    ).all()
    username_by_user_id = {user_id: username for user_id, username in user_rows}

    friend_repo = SqlAlchemyFriendRepository(db)
    summaries: list[MessageThreadSummaryResponse] = []
    for thread_id in thread_ids:
        other_user_id = other_user_by_thread.get(thread_id)
        if other_user_id is None:
            continue
        if (
            await friend_repo.get_relationship_status(
                current_user.id,
                other_user_id,
            )
            != "accepted"
        ):
            continue

        latest_message = (
            await db.execute(
                select(Message)
                .where(Message.thread_id == thread_id)
                .order_by(desc(Message.created_at))
                .limit(1)
            )
        ).scalar_one_or_none()
        if latest_message is None:
            continue

        preview = (
            await db.execute(
                select(Attachment.content).where(
                    Attachment.message_id == latest_message.id,
                    Attachment.attachment_type == AttachmentType.text,
                )
            )
        ).scalar_one_or_none()

        summaries.append(
            MessageThreadSummaryResponse(
                user_id=other_user_id,
                username=username_by_user_id.get(other_user_id, "Unknown user"),
                last_message_preview=(preview or "").strip() or "Message",
                last_message_at=latest_message.created_at,
            )
        )

    summaries.sort(key=lambda item: item.last_message_at, reverse=True)
    return summaries


@router.get("/{userId}", response_model=DirectMessageThreadResponse)
async def get_direct_messages(
    userId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    if userId == current_user.id:
        raise HTTPException(status_code=422, detail="Cannot open chat with yourself")

    target_user = await _ensure_target_user_exists(db, userId)
    await _ensure_friendship(db, current_user.id, userId)

    thread_id = await _find_direct_thread_id(db, current_user.id, userId)
    if thread_id is None:
        return DirectMessageThreadResponse(
            target_user_id=target_user.id,
            target_username=target_user.username,
            items=[],
        )

    items = await _load_thread_messages(db, thread_id, current_user.id)
    return DirectMessageThreadResponse(
        target_user_id=target_user.id,
        target_username=target_user.username,
        items=items,
    )


@router.post("/{userId}", response_model=DirectMessageItemResponse, status_code=201)
async def send_direct_message(
    userId: uuid.UUID,
    body: SendDirectMessageRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    if userId == current_user.id:
        raise HTTPException(status_code=422, detail="Cannot send message to yourself")

    target_user = await _ensure_target_user_exists(db, userId)
    await _ensure_friendship(db, current_user.id, userId)

    text = body.text.strip()
    if not text:
        raise HTTPException(status_code=422, detail="Message text cannot be empty")

    thread_id = await _find_direct_thread_id(db, current_user.id, userId)
    if thread_id is None:
        thread_id = await _create_direct_thread(db, current_user.id, userId)

    message = Message(thread_id=thread_id, sender_id=current_user.id)
    db.add(message)
    await db.flush()
    await db.refresh(message)

    db.add(
        AttachmentText(
            message_id=message.id,
            content=text,
        )
    )
    await db.flush()

    return DirectMessageItemResponse(
        id=message.id,
        sender_user_id=current_user.id,
        sender_username=current_user.username,
        text=text,
        created_at=message.created_at,
        is_mine=True,
    )
