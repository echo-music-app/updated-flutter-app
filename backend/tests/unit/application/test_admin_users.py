"""Unit tests for admin user moderation use cases."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.application.use_cases.admin_users import AdminUsersUseCases


@pytest.fixture
def mock_user_repo() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def mock_audit() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def use_cases(mock_user_repo, mock_audit) -> AdminUsersUseCases:
    return AdminUsersUseCases(user_repo=mock_user_repo, audit=mock_audit)


@pytest.mark.asyncio
async def test_list_users_returns_managed_projections(use_cases: AdminUsersUseCases, mock_user_repo: AsyncMock) -> None:
    mock_user_repo.list_managed = AsyncMock(return_value=[])
    result = await use_cases.list_users(page=1, page_size=20)
    mock_user_repo.list_managed.assert_awaited_once()
    assert isinstance(result, list)


@pytest.mark.asyncio
async def test_change_user_status_records_audit(
    use_cases: AdminUsersUseCases,
    mock_user_repo: AsyncMock,
    mock_audit: AsyncMock,
) -> None:
    user_id = uuid.uuid4()
    admin_id = uuid.uuid4()

    mock_user = MagicMock()
    mock_user.id = user_id
    mock_user.status = "active"
    mock_user_repo.get_managed = AsyncMock(return_value=mock_user)
    mock_user_repo.update_status = AsyncMock(return_value=mock_user)

    await use_cases.change_user_status(
        user_id=user_id,
        actor_admin_id=admin_id,
        new_status="disabled",
        reason="Policy violation",
    )

    mock_audit.record.assert_awaited_once()


@pytest.mark.asyncio
async def test_change_user_status_rejects_permanent_deletion(
    use_cases: AdminUsersUseCases,
) -> None:
    """User accounts cannot be permanently deleted."""
    with pytest.raises(ValueError, match="permanent"):
        await use_cases.change_user_status(
            user_id=uuid.uuid4(),
            actor_admin_id=uuid.uuid4(),
            new_status="deleted_permanently",
            reason="Test",
        )


@pytest.mark.asyncio
async def test_get_user_returns_managed_projection(use_cases: AdminUsersUseCases, mock_user_repo: AsyncMock) -> None:
    user_id = uuid.uuid4()
    expected = {"id": str(user_id), "username": "testuser", "status": "active"}
    mock_user_repo.get_managed = AsyncMock(return_value=expected)

    result = await use_cases.get_user(user_id)

    mock_user_repo.get_managed.assert_awaited_once_with(user_id)
    assert result == expected
