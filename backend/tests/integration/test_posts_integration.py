"""Integration tests for posts — attachment STI and attachment hydration."""

import pytest
import uuid6
from httpx import AsyncClient
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.attachment import Attachment, AttachmentType
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
async def test_attachment_sti_query_no_subtype_joins(async_client: AsyncClient, db_session: AsyncSession):
    """STI attachment queries must not join any subtype tables."""
    token = await _register(async_client, "sti_no_joins_1@example.com", "sti_no_joins_1")
    me = (await db_session.execute(select(User).where(User.email == "sti_no_joins_1@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    for attachment_type, extra in [
        (AttachmentType.audio_file, {"storage_key": "k.mp3", "mime_type": "audio/mpeg", "size_bytes": 1}),
        (AttachmentType.spotify_link, {"url": "https://open.spotify.com/track/x"}),
        (AttachmentType.text, {"content": "hello"}),
    ]:
        db_session.add(Attachment(id=uuid6.uuid7(), attachment_type=attachment_type, post_id=post.id, **extra))
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
    assert "attachments_text" not in joined


@pytest.mark.anyio
async def test_posts_with_attachments_integration(async_client: AsyncClient, db_session: AsyncSession):
    """Attachments are hydrated from the single attachments table and returned in post responses."""
    token = await _register(async_client, "posts_att_int_1@example.com", "posts_att_int_1")
    me = (await db_session.execute(select(User).where(User.email == "posts_att_int_1@example.com"))).scalar_one()

    post = Post(id=uuid6.uuid7(), user_id=me.id, privacy=Privacy.public)
    db_session.add(post)
    await db_session.flush()

    attachment = Attachment(
        id=uuid6.uuid7(),
        attachment_type=AttachmentType.spotify_link,
        post_id=post.id,
        url="https://open.spotify.com/track/abc123",
        track_id="abc123",
    )
    db_session.add(attachment)
    await db_session.flush()

    response = await async_client.get("/v1/me/posts", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    items = response.json()["items"]
    assert len(items) == 1
    assert len(items[0]["attachments"]) == 1
    att = items[0]["attachments"][0]
    assert att["type"] == "spotify_link"
    assert att["url"] == "https://open.spotify.com/track/abc123"
    assert att["track_id"] == "abc123"
    assert att["id"] == str(attachment.id)
