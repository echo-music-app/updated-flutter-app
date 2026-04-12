import pytest
import uuid6
from httpx import AsyncClient
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.attachment import Attachment, AttachmentType, AttachmentUrlProvider
from backend.infrastructure.persistence.models.post import Post, Privacy
from backend.infrastructure.persistence.models.user import User


async def _register(client: AsyncClient, email: str, username: str) -> str:
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
    return verify_resp.json()["access_token"]


@pytest.mark.anyio
async def test_post_create_requires_auth(async_client_no_db: AsyncClient):
    response = await async_client_no_db.post("/v1/posts", json={"privacy": "Public"})
    assert response.status_code == 401


@pytest.mark.anyio
async def test_post_create_invalid_privacy(async_client: AsyncClient):
    token = await _register(async_client, "posts_contract_1@example.com", "posts_contract_1")
    response = await async_client.post(
        "/v1/posts",
        json={"privacy": "Invalid"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_post_create_success(async_client: AsyncClient):
    token = await _register(async_client, "posts_contract_2@example.com", "posts_contract_2")
    response = await async_client.post(
        "/v1/posts",
        json={"privacy": "Public"},
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 201
    body = response.json()
    assert body["privacy"] == "Public"
    assert body["attachments"] == []


@pytest.mark.anyio
async def test_get_me_posts_contract(async_client: AsyncClient):
    token = await _register(async_client, "posts_contract_3@example.com", "posts_contract_3")
    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"items", "count", "page_size", "next_cursor"}


@pytest.mark.anyio
async def test_get_user_posts_malformed_uuid(async_client: AsyncClient):
    token = await _register(async_client, "posts_contract_4@example.com", "posts_contract_4")
    response = await async_client.get(
        "/v1/user/not-a-uuid/posts",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert response.status_code == 422


@pytest.mark.anyio
async def test_get_following_posts_contract(async_client: AsyncClient):
    token = await _register(async_client, "posts_contract_5@example.com", "posts_contract_5")
    response = await async_client.get("/v1/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    body = response.json()
    assert set(body.keys()) == {"items", "count", "page_size", "next_cursor"}


# ---------------------------------------------------------------------------
# T038: Attachment object variant shapes
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_attachment_spotify_link_shape(async_client: AsyncClient, db_session: AsyncSession):
    """spotify_link attachment must expose url and track_id fields."""
    from sqlalchemy import select

    token = await _register(async_client, "posts_contract_6@example.com", "posts_contract_6")
    me = (await db_session.execute(select(User).where(User.email == "posts_contract_6@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.spotify_link,
            post_id=post.id,
            url="https://open.spotify.com/track/abc",
            track_id="abc",
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["type"] == "spotify_link"
    assert att["url"] == "https://open.spotify.com/track/abc"
    assert att["track_id"] == "abc"
    assert att["content"] is None
    assert att["storage_key"] is None


@pytest.mark.anyio
async def test_attachment_text_shape(async_client: AsyncClient, db_session: AsyncSession):
    """text attachment must expose content field and null url/track_id."""
    from sqlalchemy import select

    token = await _register(async_client, "posts_contract_7@example.com", "posts_contract_7")
    me = (await db_session.execute(select(User).where(User.email == "posts_contract_7@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.text,
            post_id=post.id,
            content="hello world",
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["type"] == "text"
    assert att["content"] == "hello world"
    assert att["url"] is None
    assert att["track_id"] is None


@pytest.mark.anyio
async def test_attachment_audio_file_shape(async_client: AsyncClient, db_session: AsyncSession):
    """audio_file attachment must expose storage_key, mime_type, and size_bytes."""
    from sqlalchemy import select

    token = await _register(async_client, "posts_contract_8@example.com", "posts_contract_8")
    me = (await db_session.execute(select(User).where(User.email == "posts_contract_8@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="audio/song.mp3",
            mime_type="audio/mpeg",
            size_bytes=54321,
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["type"] == "audio_file"
    assert att["storage_key"] == "audio/song.mp3"
    assert att["mime_type"] == "audio/mpeg"
    assert att["size_bytes"] == 54321


# ---------------------------------------------------------------------------
# T041: Signer contract coverage (default nginx, CloudFront override, fail-closed)
# ---------------------------------------------------------------------------


@pytest.mark.anyio
async def test_attachment_nginx_default_url_signing(async_client: AsyncClient, db_session: AsyncSession):
    """Default nginx_secure_link provider signs storage-key attachments and sets url_provider."""
    from sqlalchemy import select

    token = await _register(async_client, "posts_contract_9@example.com", "posts_contract_9")
    me = (await db_session.execute(select(User).where(User.email == "posts_contract_9@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="media/default.mp3",
            mime_type="audio/mpeg",
            size_bytes=100,
            url_provider_override=None,
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["url_provider"] == "nginx_secure_link"
    assert att["url"] is not None
    assert "md5=" in att["url"]


@pytest.mark.anyio
async def test_attachment_cloudfront_override_url_signing(async_client: AsyncClient, db_session: AsyncSession):
    """CloudFront url_provider_override produces a CloudFront-signed URL."""
    from sqlalchemy import select

    token = await _register(async_client, "posts_contract_10@example.com", "posts_contract_10")
    me = (await db_session.execute(select(User).where(User.email == "posts_contract_10@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    db_session.add(
        Attachment(
            id=uuid6.uuid7(),
            attachment_type=AttachmentType.audio_file,
            post_id=post.id,
            storage_key="media/cf.mp3",
            mime_type="audio/mpeg",
            size_bytes=200,
            url_provider_override=AttachmentUrlProvider.cloudfront,
        )
    )
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    att = response.json()["items"][0]["attachments"][0]
    assert att["url_provider"] == "cloudfront"
    assert att["url"] is not None
    assert "Key-Pair-Id=" in att["url"]
