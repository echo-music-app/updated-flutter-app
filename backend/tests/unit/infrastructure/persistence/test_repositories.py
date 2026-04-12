"""Unit tests for persistence repositories — covering uncovered branches."""

from datetime import UTC, datetime, timedelta
from unittest.mock import AsyncMock, MagicMock

import pytest
import uuid6

from backend.infrastructure.persistence.models.attachment import Attachment
from backend.infrastructure.persistence.models.auth import RefreshToken
from backend.infrastructure.persistence.models.spotify_credentials import SpotifyCredentials
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.post_repository import SqlAlchemyPostRepository
from backend.infrastructure.persistence.repositories.spotify_credentials_repository import (
    SqlAlchemySpotifyCredentialsRepository,
)
from backend.infrastructure.persistence.repositories.token_repository import SqlAlchemyTokenRepository
from backend.infrastructure.persistence.repositories.user_repository import SqlAlchemyUserRepository


def _mock_session():
    session = MagicMock()
    session.execute = AsyncMock()
    session.flush = AsyncMock()
    session.delete = AsyncMock()
    return session


def _scalars_result(values: list):
    inner = MagicMock()
    inner.scalars.return_value.all.return_value = values
    return inner


def _scalar_result(value):
    result = MagicMock()
    result.scalar_one_or_none.return_value = value
    return result


# ---------------------------------------------------------------------------
# SqlAlchemyUserRepository
# ---------------------------------------------------------------------------


class TestUserRepository:
    async def test_get_by_id_returns_user(self):
        session = _mock_session()
        user = MagicMock(spec=User)
        user.id = uuid6.uuid7()
        session.execute.return_value = _scalar_result(user)

        repo = SqlAlchemyUserRepository(session)
        result = await repo.get_by_id(user.id)

        assert result is user

    async def test_get_by_id_returns_none_when_not_found(self):
        session = _mock_session()
        session.execute.return_value = _scalar_result(None)

        repo = SqlAlchemyUserRepository(session)
        result = await repo.get_by_id(uuid6.uuid7())

        assert result is None


# ---------------------------------------------------------------------------
# SqlAlchemyTokenRepository
# ---------------------------------------------------------------------------


class TestTokenRepository:
    async def test_revoke_refresh_does_nothing_when_not_found(self):
        session = _mock_session()
        session.execute.return_value = _scalar_result(None)

        repo = SqlAlchemyTokenRepository(session)
        # Should not raise
        await repo.revoke_refresh(uuid6.uuid7(), datetime.now(UTC))

    async def test_revoke_refresh_sets_revoked_at_when_found(self):
        session = _mock_session()
        refresh_token = MagicMock(spec=RefreshToken)
        refresh_token.revoked_at = None
        session.execute.return_value = _scalar_result(refresh_token)

        repo = SqlAlchemyTokenRepository(session)
        now = datetime.now(UTC)
        await repo.revoke_refresh(uuid6.uuid7(), now)

        assert refresh_token.revoked_at == now


# ---------------------------------------------------------------------------
# SqlAlchemySpotifyCredentialsRepository
# ---------------------------------------------------------------------------


class TestSpotifyCredentialsRepository:
    async def test_update_tokens_skips_refresh_when_none(self):
        session = _mock_session()
        cred = MagicMock(spec=SpotifyCredentials)
        cred.refresh_token = b"old_refresh"
        session.execute.return_value = _scalar_result(cred)

        repo = SqlAlchemySpotifyCredentialsRepository(session)
        new_expiry = datetime.now(UTC) + timedelta(hours=1)
        await repo.update_tokens(uuid6.uuid7(), b"new_access", None, new_expiry)

        assert cred.access_token == b"new_access"
        assert cred.refresh_token == b"old_refresh"
        assert cred.token_expiry == new_expiry

    async def test_update_tokens_updates_refresh_when_provided(self):
        session = _mock_session()
        cred = MagicMock(spec=SpotifyCredentials)
        session.execute.return_value = _scalar_result(cred)

        repo = SqlAlchemySpotifyCredentialsRepository(session)
        new_expiry = datetime.now(UTC) + timedelta(hours=1)
        await repo.update_tokens(uuid6.uuid7(), b"new_access", b"new_refresh", new_expiry)

        assert cred.access_token == b"new_access"
        assert cred.refresh_token == b"new_refresh"
        assert cred.token_expiry == new_expiry


# ---------------------------------------------------------------------------
# SqlAlchemyPostRepository
# ---------------------------------------------------------------------------


class TestPostRepository:
    @pytest.mark.anyio
    async def test_list_for_authors_empty_ids_returns_empty(self):
        """Empty author_ids list must short-circuit without hitting the DB."""
        session = _mock_session()
        repo = SqlAlchemyPostRepository(session)

        posts, attachment_map, next_cursor = await repo.list_for_authors(
            author_ids=[], page_size=10, cursor_created_at=None, cursor_id=None
        )

        assert posts == []
        assert attachment_map == {}
        assert next_cursor is None
        session.execute.assert_not_called()

    @pytest.mark.anyio
    async def test_list_for_authors_with_cursor_applies_filter(self):
        """Passing cursor values must include the cursor WHERE clause."""
        session = _mock_session()
        # First execute: posts query; second execute: attachments query
        session.execute.side_effect = [_scalars_result([]), _scalars_result([])]

        repo = SqlAlchemyPostRepository(session)
        now = datetime.now(UTC)
        posts, attachment_map, next_cursor = await repo.list_for_authors(
            author_ids=[uuid6.uuid7()],
            page_size=10,
            cursor_created_at=now,
            cursor_id=uuid6.uuid7(),
        )

        assert posts == []
        assert attachment_map == {}
        assert next_cursor is None
        # Cursor branch executed — DB was queried
        assert session.execute.call_count == 1

    @pytest.mark.anyio
    async def test_list_for_authors_attachment_with_null_post_id_skipped(self):
        """Attachments whose post_id is None must be skipped in the attachment map."""
        session = _mock_session()
        user_id = uuid6.uuid7()
        post_id = uuid6.uuid7()

        post = MagicMock()
        post.id = post_id
        post.created_at = datetime.now(UTC)

        orphan_attachment = MagicMock(spec=Attachment)
        orphan_attachment.post_id = None

        session.execute.side_effect = [
            _scalars_result([post]),
            _scalars_result([orphan_attachment]),
        ]

        repo = SqlAlchemyPostRepository(session)
        posts, attachment_map, _ = await repo.list_for_authors(author_ids=[user_id], page_size=10, cursor_created_at=None, cursor_id=None)

        assert posts == [post]
        assert attachment_map == {}
