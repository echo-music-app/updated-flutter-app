from datetime import UTC, datetime
from types import SimpleNamespace
from unittest.mock import AsyncMock

import pytest
import uuid6

from backend.application.posts.use_cases import CreatePostUseCase, ListPostsUseCase, PostDTO, compute_next_cursor
from backend.core.config import Settings
from backend.domain.posts.value_objects.post_cursor import PostCursor, encode_cursor


@pytest.mark.anyio
async def test_create_post_use_case_rejects_invalid_privacy():
    repo = AsyncMock()
    use_case = CreatePostUseCase(post_repo=repo)

    with pytest.raises(ValueError):
        await use_case.execute(user_id=uuid6.uuid7(), privacy="Invalid")


@pytest.mark.anyio
async def test_create_post_use_case_returns_empty_attachments():
    post = SimpleNamespace(
        id=uuid6.uuid7(),
        user_id=uuid6.uuid7(),
        privacy=SimpleNamespace(value="Public"),
        created_at=datetime.now(UTC),
        updated_at=datetime.now(UTC),
    )
    repo = AsyncMock()
    repo.create.return_value = post

    use_case = CreatePostUseCase(post_repo=repo)
    result = await use_case.execute(user_id=post.user_id, privacy="Public")

    assert result.id == post.id
    assert result.attachments == []


@pytest.mark.anyio
async def test_list_posts_use_case_provider_override_and_default():
    now = datetime.now(UTC)
    post_id = uuid6.uuid7()
    user_id = uuid6.uuid7()

    posts = [
        SimpleNamespace(
            id=post_id,
            user_id=user_id,
            privacy=SimpleNamespace(value="Public"),
            created_at=now,
            updated_at=now,
        )
    ]
    attachments_map = {
        post_id: [
            SimpleNamespace(
                id=uuid6.uuid7(),
                attachment_type=SimpleNamespace(value="audio_file"),
                created_at=now,
                content=None,
                url=None,
                track_id=None,
                storage_key="a/b/c.mp3",
                mime_type="audio/mpeg",
                size_bytes=123,
                url_provider_override="cloudfront",
            ),
            SimpleNamespace(
                id=uuid6.uuid7(),
                attachment_type=SimpleNamespace(value="audio_file"),
                created_at=now,
                content=None,
                url=None,
                track_id=None,
                storage_key="a/b/d.mp3",
                mime_type="audio/mpeg",
                size_bytes=456,
                url_provider_override=None,
            ),
        ]
    }

    post_repo = AsyncMock()
    post_repo.list_for_authors.return_value = (posts, attachments_map, None)
    friend_repo = AsyncMock()

    nginx = AsyncMock()
    nginx.sign.return_value = "https://nginx/signed"
    cloudfront = AsyncMock()
    cloudfront.sign.return_value = "https://cloudfront/signed"

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={"nginx_secure_link": nginx, "cloudfront": cloudfront},
        settings=settings,
    )

    result = await use_case.list_my_posts(user_id=user_id, page_size=20, cursor=None)

    assert result.count == 1
    assert result.items[0].attachments[0].url_provider == "cloudfront"
    assert result.items[0].attachments[0].url == "https://cloudfront/signed"
    assert result.items[0].attachments[1].url_provider == "nginx_secure_link"
    assert result.items[0].attachments[1].url == "https://nginx/signed"


@pytest.mark.anyio
async def test_list_posts_use_case_signing_failure_fails_closed():
    now = datetime.now(UTC)
    post_id = uuid6.uuid7()
    user_id = uuid6.uuid7()

    posts = [
        SimpleNamespace(
            id=post_id,
            user_id=user_id,
            privacy=SimpleNamespace(value="Public"),
            created_at=now,
            updated_at=now,
        )
    ]
    attachments_map = {
        post_id: [
            SimpleNamespace(
                id=uuid6.uuid7(),
                attachment_type=SimpleNamespace(value="audio_file"),
                created_at=now,
                content=None,
                url=None,
                track_id=None,
                storage_key="a/b/c.mp3",
                mime_type="audio/mpeg",
                size_bytes=123,
                url_provider_override=None,
            )
        ]
    }

    post_repo = AsyncMock()
    post_repo.list_for_authors.return_value = (posts, attachments_map, None)
    friend_repo = AsyncMock()

    nginx = AsyncMock()
    nginx.sign.side_effect = RuntimeError("signing failed")

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={"nginx_secure_link": nginx},
        settings=settings,
    )

    result = await use_case.list_my_posts(user_id=user_id, page_size=20, cursor=None)

    assert result.items[0].attachments[0].url is None
    assert result.items[0].attachments[0].url_provider is None
    assert result.items[0].attachments[0].expires_at is None


@pytest.mark.anyio
async def test_list_following_feed_uses_friend_repository():
    user_id = uuid6.uuid7()
    author_id = uuid6.uuid7()
    post_repo = AsyncMock()
    post_repo.list_for_authors.return_value = ([], {}, None)
    friend_repo = AsyncMock()
    friend_repo.get_following_user_ids.return_value = [author_id]

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={},
        settings=settings,
    )

    await use_case.list_following_feed(user_id=user_id, page_size=10, cursor=None)
    friend_repo.get_following_user_ids.assert_awaited_once_with(user_id)
    post_repo.list_for_authors.assert_awaited_once()


@pytest.mark.anyio
async def test_list_user_posts_calls_list_for_authors():
    target_user_id = uuid6.uuid7()
    post_repo = AsyncMock()
    post_repo.list_for_authors.return_value = ([], {}, None)
    friend_repo = AsyncMock()

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={},
        settings=settings,
    )

    await use_case.list_user_posts(target_user_id=target_user_id, page_size=10, cursor=None)
    post_repo.list_for_authors.assert_awaited_once_with(author_ids=[target_user_id], page_size=10, cursor_created_at=None, cursor_id=None)


@pytest.mark.anyio
async def test_list_following_feed_empty_returns_empty_list():
    user_id = uuid6.uuid7()
    post_repo = AsyncMock()
    friend_repo = AsyncMock()
    friend_repo.get_following_user_ids.return_value = []

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={},
        settings=settings,
    )

    result = await use_case.list_following_feed(user_id=user_id, page_size=10, cursor=None)
    assert result.items == []
    assert result.count == 0
    assert result.page_size == 10
    assert result.next_cursor is None


@pytest.mark.anyio
async def test_cursor_parsing_logic():
    user_id = uuid6.uuid7()
    post_repo = AsyncMock()
    post_repo.list_for_authors.return_value = ([], {}, None)
    friend_repo = AsyncMock()

    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://echo:echo@postgres:5432/echo",
        secret_key="test-secret-key",
        spotify_token_encryption_key="a" * 64,
    )

    use_case = ListPostsUseCase(
        post_repo=post_repo,
        friend_repo=friend_repo,
        signers={},
        settings=settings,
    )

    # Test with cursor
    cursor = encode_cursor(PostCursor(created_at=datetime.now(UTC), id=uuid6.uuid7()))
    await use_case.list_my_posts(user_id=user_id, page_size=10, cursor=cursor)

    # Verify the call includes cursor data
    call_args = post_repo.list_for_authors.call_args
    assert "cursor_created_at" in call_args.kwargs
    assert "cursor_id" in call_args.kwargs


@pytest.mark.anyio
async def test_compute_next_cursor():
    # Test when posts < page_size (no next cursor)
    posts = [
        PostDTO(
            id=uuid6.uuid7(),
            user_id=uuid6.uuid7(),
            privacy="Public",
            attachments=[],
            created_at=datetime.now(UTC),
            updated_at=datetime.now(UTC),
        )
    ]
    result = compute_next_cursor(posts, page_size=5)
    assert result is None

    # Test when posts == page_size (has next cursor)
    posts.extend(
        [
            PostDTO(
                id=uuid6.uuid7(),
                user_id=uuid6.uuid7(),
                privacy="Public",
                attachments=[],
                created_at=datetime.now(UTC),
                updated_at=datetime.now(UTC),
            )
            for _ in range(4)
        ]
    )
    result = compute_next_cursor(posts, page_size=5)
    assert result is not None
