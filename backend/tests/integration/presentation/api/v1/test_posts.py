from datetime import UTC, datetime, timedelta

import pytest
import uuid6
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.attachment import Attachment, AttachmentType, AttachmentUrlProvider
from backend.infrastructure.persistence.models.friend import Friend, FriendStatus
from backend.infrastructure.persistence.models.post import Post, Privacy
from backend.infrastructure.persistence.models.user import User, UserStatus


async def _register(client: AsyncClient, email: str, username: str) -> tuple[str, str]:
    reg_resp = await client.post(
        "/v1/auth/register",
        json={"email": email, "username": username, "password": "password123"},
    )
    assert reg_resp.status_code == 201
    verification_code = reg_resp.json()["verification_code"]
    verify_resp = await client.post(
        "/v1/auth/verify-email",
        json={"email": email, "code": verification_code},
    )
    assert verify_resp.status_code == 200
    data = verify_resp.json()
    return data["access_token"], data["refresh_token"]


@pytest.mark.anyio
async def test_create_post_persists_authenticated_user(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_1@example.com", "posts_int_1")

    response = await async_client.post(
        "/v1/posts",
        json={"privacy": "Public"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201

    body = response.json()
    post = (await db_session.execute(select(Post).where(Post.id == body["id"]))).scalar_one()
    assert str(post.user_id) == body["user_id"]
    assert post.privacy == Privacy.public


@pytest.mark.anyio
async def test_list_my_posts_filters_only_current_user(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_2@example.com", "posts_int_2")
    other = User(
        id=uuid6.uuid7(),
        email="other_posts_int_2@example.com",
        username="other_posts_int_2",
        password_hash="x",
        status=UserStatus.pending,
    )
    db_session.add(other)
    await db_session.flush()

    me = (await db_session.execute(select(User).where(User.email == "posts_int_2@example.com"))).scalar_one()
    db_session.add(Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public))
    db_session.add(Post(id=uuid6.uuid7(), user_id=other.id, privacy=Privacy.public))
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["user_id"] == str(me.id)


@pytest.mark.anyio
async def test_list_user_posts_filters_target_user(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_3@example.com", "posts_int_3")
    target = User(
        id=uuid6.uuid7(),
        email="target_posts_int_3@example.com",
        username="target_posts_int_3",
        password_hash="x",
        status=UserStatus.pending,
    )
    other = User(
        id=uuid6.uuid7(),
        email="other_posts_int_3@example.com",
        username="other_posts_int_3",
        password_hash="x",
        status=UserStatus.pending,
    )
    db_session.add_all([target, other])
    await db_session.flush()

    db_session.add(Post(id=uuid6.uuid7(), user_id=target.id, privacy=Privacy.public))
    db_session.add(Post(id=uuid6.uuid7(), user_id=other.id, privacy=Privacy.public))
    await db_session.flush()

    response = await async_client.get(
        f"/v1/user/{target.id}/posts",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["user_id"] == str(target.id)


@pytest.mark.anyio
async def test_list_following_feed_uses_accepted_friend_relations(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_4@example.com", "posts_int_4")
    me = (await db_session.execute(select(User).where(User.email == "posts_int_4@example.com"))).scalar_one()

    followed = User(
        id=uuid6.uuid7(),
        email="followed_posts_int_4@example.com",
        username="followed_posts_int_4",
        password_hash="x",
        status=UserStatus.pending,
    )
    not_followed = User(
        id=uuid6.uuid7(),
        email="not_followed_posts_int_4@example.com",
        username="not_followed_posts_int_4",
        password_hash="x",
        status=UserStatus.pending,
    )
    db_session.add_all([followed, not_followed])
    await db_session.flush()

    user1, user2 = sorted([me.id, followed.id])
    db_session.add(Friend(user1_id=user1, user2_id=user2, status=FriendStatus.accepted))

    db_session.add(Post(id=uuid6.uuid7(), user_id=followed.id, privacy=Privacy.public))
    db_session.add(Post(id=uuid6.uuid7(), user_id=not_followed.id, privacy=Privacy.public))
    await db_session.flush()

    response = await async_client.get("/v1/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert items[0]["user_id"] == str(followed.id)


@pytest.mark.anyio
async def test_attachments_loaded_without_subtype_joins(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_5@example.com", "posts_int_5")
    me = (await db_session.execute(select(User).where(User.email == "posts_int_5@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="audio/file.mp3",
            mime_type="audio/mpeg",
            size_bytes=123,
            url_provider_override=AttachmentUrlProvider.cloudfront,
        )
    )
    await db_session.flush()

    executed: list[str] = []

    from sqlalchemy import event

    def _capture(conn, cursor, statement, parameters, context, executemany):
        executed.append(statement)

    sync_engine = db_session.bind.sync_engine
    event.listen(sync_engine, "before_cursor_execute", _capture)
    try:
        response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    finally:
        event.remove(sync_engine, "before_cursor_execute", _capture)

    assert response.status_code == 200
    joined = "\n".join(executed).lower()
    assert "attachments_audio_file" not in joined
    assert "attachments_spotify_link" not in joined
    assert "attachments_soundcloud_link" not in joined
    assert "attachments_text" not in joined


@pytest.mark.anyio
async def test_signed_attachment_url_present_with_provider(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_6@example.com", "posts_int_6")
    me = (await db_session.execute(select(User).where(User.email == "posts_int_6@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="media/song.mp3",
            mime_type="audio/mpeg",
            size_bytes=55,
            url_provider_override=AttachmentUrlProvider.cloudfront,
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    attachment = response.json()["items"][0]["attachments"][0]
    assert attachment["url"] is not None
    assert attachment["url_provider"] in {"cloudfront", "nginx_secure_link"}


@pytest.mark.anyio
async def test_cursor_ordering_desc(async_client: AsyncClient, db_session: AsyncSession):
    token, _ = await _register(async_client, "posts_int_7@example.com", "posts_int_7")
    me = (await db_session.execute(select(User).where(User.email == "posts_int_7@example.com"))).scalar_one()

    older = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public, created_at=datetime.now(UTC) - timedelta(minutes=1))
    newer = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public, created_at=datetime.now(UTC))
    db_session.add_all([older, newer])
    await db_session.flush()

    response = await async_client.get("/v1/me/posts?page_size=2", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 2
    assert items[0]["id"] == str(newer.id)


@pytest.mark.anyio
async def test_signed_url_expiry_within_5_minutes(async_client: AsyncClient, db_session: AsyncSession):
    """Signed attachment URLs must use a fixed 5-minute TTL."""
    token, _ = await _register(async_client, "posts_int_8@example.com", "posts_int_8")
    me = (await db_session.execute(select(User).where(User.email == "posts_int_8@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="media/expiry-test.mp3",
            mime_type="audio/mpeg",
            size_bytes=42,
        )
    )
    await db_session.flush()

    before = datetime.now(UTC)
    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["url"] is not None

    import re

    url = att["url"]
    # nginx_secure_link embeds 'expires=<unix_ts>' in the URL query string
    match = re.search(r"expires=(\d+)", url)
    assert match, f"No expires param found in signed URL: {url}"
    expires_ts = int(match.group(1))
    five_minutes = 300
    tolerance = 10
    assert expires_ts <= int(before.timestamp()) + five_minutes + tolerance
    assert expires_ts >= int(before.timestamp()) + five_minutes - tolerance
