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
from backend.infrastructure.persistence.models.post import Privacy
from backend.infrastructure.persistence.models.post_interaction import PostActivityType
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
    like_count: int = 0
    comment_count: int = 0
    current_user_liked: bool = False


class PostEngagementResponse(BaseModel):
    post_id: uuid.UUID
    like_count: int
    comment_count: int
    current_user_liked: bool


class CreatePostCommentRequest(BaseModel):
    content: str = Field(..., min_length=1, max_length=500)


class PostCommentResponse(BaseModel):
    id: uuid.UUID
    post_id: uuid.UUID
    user_id: uuid.UUID
    username: str
    content: str
    created_at: datetime


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
        like_count=item.like_count,
        comment_count=item.comment_count,
        current_user_liked=item.current_user_liked,
    )


async def _assert_can_interact_with_post(
    *,
    post_id: uuid.UUID,
    current_user: User,
    post_repo: SqlAlchemyPostRepository,
    friend_repo: SqlAlchemyFriendRepository,
):
    post = await post_repo.get_by_id(post_id)
    if post is None:
        raise HTTPException(status_code=404, detail="Post not found")
    if post.user_id == current_user.id:
        return post
    if post.privacy == Privacy.only_me:
        raise HTTPException(status_code=403, detail="You cannot interact with this post")
    are_friends = await friend_repo.are_friends(current_user.id, post.user_id)
    if not are_friends:
        raise HTTPException(status_code=403, detail="Only friends can interact with this post")
    return post


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
        like_count=0,
        comment_count=0,
        current_user_liked=False,
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
    use_case = _build_list_use_case(db)
    result = await use_case.list_user_posts(
        target_user_id=userId,
        viewer_user_id=current_user.id,
        page_size=page_size,
        cursor=cursor,
    )
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


@router.post("/posts/{postId}/likes", response_model=PostEngagementResponse)
async def like_post(
    postId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    post_repo = SqlAlchemyPostRepository(db)
    friend_repo = SqlAlchemyFriendRepository(db)
    post = await _assert_can_interact_with_post(
        post_id=postId,
        current_user=current_user,
        post_repo=post_repo,
        friend_repo=friend_repo,
    )
    created = await post_repo.add_like(post_id=postId, user_id=current_user.id)
    if created and post.user_id != current_user.id:
        await post_repo.create_activity_notification(
            recipient_user_id=post.user_id,
            actor_user_id=current_user.id,
            post_id=post.id,
            activity_type=PostActivityType.like,
        )
    like_count, comment_count, current_user_liked = await post_repo.get_post_engagement(
        post_id=postId,
        user_id=current_user.id,
    )
    return PostEngagementResponse(
        post_id=postId,
        like_count=like_count,
        comment_count=comment_count,
        current_user_liked=current_user_liked,
    )


@router.delete("/posts/{postId}/likes", response_model=PostEngagementResponse)
async def unlike_post(
    postId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    post_repo = SqlAlchemyPostRepository(db)
    friend_repo = SqlAlchemyFriendRepository(db)
    await _assert_can_interact_with_post(
        post_id=postId,
        current_user=current_user,
        post_repo=post_repo,
        friend_repo=friend_repo,
    )
    await post_repo.remove_like(post_id=postId, user_id=current_user.id)
    like_count, comment_count, current_user_liked = await post_repo.get_post_engagement(
        post_id=postId,
        user_id=current_user.id,
    )
    return PostEngagementResponse(
        post_id=postId,
        like_count=like_count,
        comment_count=comment_count,
        current_user_liked=current_user_liked,
    )


@router.get("/posts/{postId}/comments", response_model=list[PostCommentResponse])
async def list_post_comments(
    postId: uuid.UUID,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    post_repo = SqlAlchemyPostRepository(db)
    friend_repo = SqlAlchemyFriendRepository(db)
    await _assert_can_interact_with_post(
        post_id=postId,
        current_user=current_user,
        post_repo=post_repo,
        friend_repo=friend_repo,
    )
    rows = await post_repo.list_comments_with_authors(post_id=postId)
    return [
        PostCommentResponse(
            id=comment.id,
            post_id=comment.post_id,
            user_id=comment.user_id,
            username=username,
            content=comment.content,
            created_at=comment.created_at,
        )
        for comment, username in rows
    ]


@router.post("/posts/{postId}/comments", response_model=PostCommentResponse, status_code=201)
async def create_post_comment(
    postId: uuid.UUID,
    body: CreatePostCommentRequest,
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db_session),
):
    post_repo = SqlAlchemyPostRepository(db)
    friend_repo = SqlAlchemyFriendRepository(db)
    post = await _assert_can_interact_with_post(
        post_id=postId,
        current_user=current_user,
        post_repo=post_repo,
        friend_repo=friend_repo,
    )
    comment = await post_repo.create_comment(
        post_id=postId,
        user_id=current_user.id,
        content=body.content,
    )
    if post.user_id != current_user.id:
        await post_repo.create_activity_notification(
            recipient_user_id=post.user_id,
            actor_user_id=current_user.id,
            post_id=post.id,
            activity_type=PostActivityType.comment,
            comment_preview=comment.content[:200],
        )
    return PostCommentResponse(
        id=comment.id,
        post_id=comment.post_id,
        user_id=comment.user_id,
        username=current_user.username,
        content=comment.content,
        created_at=comment.created_at,
    )
