import uuid
from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field
from sqlalchemy.ext.asyncio import AsyncSession

from backend.adapters.security.cloudfront_signed_url_signer import CloudFrontSignedUrlSigner
from backend.adapters.security.nginx_secure_link_signer import NginxSecureLinkSigner
from backend.application.posts.use_cases import CreatePostUseCase, ListPostsUseCase
from backend.core.config import get_settings
from backend.core.database import get_db_session
from backend.core.deps import get_current_user
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.friend_repository import SqlAlchemyFriendRepository
from backend.infrastructure.persistence.repositories.post_repository import SqlAlchemyPostRepository

router = APIRouter(tags=["posts"])


class CreatePostRequest(BaseModel):
    privacy: str = Field(..., examples=["Public"])
    text: str | None = Field(default=None, examples=["Sharing a new track today"])
    spotify_url: str | None = Field(default=None, examples=["https://open.spotify.com/track/xyz"])


class AttachmentResponse(BaseModel):
    id: uuid.UUID
    type: str
    created_at: datetime
    content: str | None = None
    url: str | None = None
    url_provider: str | None = None
    expires_at: datetime | None = None
    track_id: str | None = None
    storage_key: str | None = None
    mime_type: str | None = None
    size_bytes: int | None = None


class PostResponse(BaseModel):
    id: uuid.UUID
    user_id: uuid.UUID
    privacy: str
    attachments: list[AttachmentResponse]
    created_at: datetime
    updated_at: datetime


class PostListResponse(BaseModel):
    items: list[PostResponse]
    count: int
    page_size: int
    next_cursor: str | None


def _build_list_use_case(db: AsyncSession) -> ListPostsUseCase:
    settings = get_settings()
    signers = {
        "nginx_secure_link": NginxSecureLinkSigner(
            base_url=settings.nginx_secure_link_base_url,
            secret=settings.nginx_secure_link_secret.get_secret_value(),
        ),
        "cloudfront": CloudFrontSignedUrlSigner(
            base_url=settings.cloudfront_base_url,
            key_pair_id=settings.cloudfront_key_pair_id,
            private_key=settings.cloudfront_private_key.get_secret_value(),
        ),
    }
    return ListPostsUseCase(
        post_repo=SqlAlchemyPostRepository(db),
        friend_repo=SqlAlchemyFriendRepository(db),
        signers=signers,
        settings=settings,
    )


def _to_post_response(item) -> PostResponse:
    attachments = [
        AttachmentResponse(
            id=attachment.id,
            type=attachment.type,
            created_at=attachment.created_at,
            content=attachment.content,
            url=attachment.url,
            url_provider=attachment.url_provider,
            expires_at=attachment.expires_at,
            track_id=attachment.track_id,
            storage_key=attachment.storage_key,
            mime_type=attachment.mime_type,
            size_bytes=attachment.size_bytes,
        )
        for attachment in item.attachments
    ]
    return PostResponse(
        id=item.id,
        user_id=item.user_id,
        privacy=item.privacy,
        attachments=attachments,
        created_at=item.created_at,
        updated_at=item.updated_at,
    )


@router.post("/posts", response_model=PostResponse, status_code=201)
async def create_post(
    body: CreatePostRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    use_case = CreatePostUseCase(SqlAlchemyPostRepository(db))
    try:
        created = await use_case.execute(
            user_id=current_user.id,
            privacy=body.privacy,
            text=body.text,
            spotify_url=body.spotify_url,
        )
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return PostResponse(
        id=created.id,
        user_id=created.user_id,
        privacy=created.privacy,
        attachments=[],
        created_at=created.created_at,
        updated_at=created.updated_at,
    )


@router.get("/me/posts", response_model=PostListResponse)
async def list_my_posts(
    page_size: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    use_case = _build_list_use_case(db)
    result = await use_case.list_my_posts(user_id=current_user.id, page_size=page_size, cursor=cursor)
    return PostListResponse(
        items=[_to_post_response(item) for item in result.items],
        count=result.count,
        page_size=result.page_size,
        next_cursor=result.next_cursor,
    )


@router.get("/user/{userId}/posts", response_model=PostListResponse)
async def list_user_posts(
    userId: uuid.UUID,
    page_size: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    _ = current_user
    use_case = _build_list_use_case(db)
    result = await use_case.list_user_posts(target_user_id=userId, page_size=page_size, cursor=cursor)
    return PostListResponse(
        items=[_to_post_response(item) for item in result.items],
        count=result.count,
        page_size=result.page_size,
        next_cursor=result.next_cursor,
    )


@router.get("/posts", response_model=PostListResponse)
async def list_following_posts(
    page_size: int = Query(default=20, ge=1, le=100),
    cursor: str | None = Query(default=None),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    use_case = _build_list_use_case(db)
    result = await use_case.list_following_feed(user_id=current_user.id, page_size=page_size, cursor=cursor)

    return PostListResponse(
        items=[_to_post_response(item) for item in result.items],
        count=result.count,
        page_size=result.page_size,
        next_cursor=result.next_cursor,
    )
