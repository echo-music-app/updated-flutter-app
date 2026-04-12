"""Unit tests for admin content moderation use cases."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.application.use_cases.admin_content import AdminContentUseCases


@pytest.fixture
def mock_content_repo() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def mock_audit() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def use_cases(mock_content_repo, mock_audit) -> AdminContentUseCases:
    return AdminContentUseCases(content_repo=mock_content_repo, audit=mock_audit)


@pytest.mark.asyncio
async def test_list_content_returns_projections(use_cases: AdminContentUseCases, mock_content_repo: AsyncMock) -> None:
    mock_content_repo.list_managed = AsyncMock(return_value=[])
    result = await use_cases.list_content(page=1, page_size=20)
    assert isinstance(result, list)


@pytest.mark.asyncio
async def test_remove_content_records_audit(
    use_cases: AdminContentUseCases,
    mock_content_repo: AsyncMock,
    mock_audit: AsyncMock,
) -> None:
    content_id = uuid.uuid4()
    admin_id = uuid.uuid4()
    mock_content = MagicMock()
    mock_content.id = content_id
    mock_content_repo.get_managed = AsyncMock(return_value=mock_content)
    mock_content_repo.apply_action = AsyncMock(return_value=mock_content)

    await use_cases.apply_content_action(
        content_id=content_id,
        actor_admin_id=admin_id,
        action_type="remove",
        reason="Policy violation",
        confirmed=False,
    )

    mock_audit.record.assert_awaited_once()


@pytest.mark.asyncio
async def test_permanent_delete_requires_confirmation(
    use_cases: AdminContentUseCases,
    mock_content_repo: AsyncMock,
) -> None:
    mock_content_repo.get_managed = AsyncMock(return_value=MagicMock())

    with pytest.raises(ValueError, match="confirmation"):
        await use_cases.apply_content_action(
            content_id=uuid.uuid4(),
            actor_admin_id=uuid.uuid4(),
            action_type="delete_permanently",
            reason="Test",
            confirmed=False,
        )


@pytest.mark.asyncio
async def test_get_content_returns_projection(use_cases: AdminContentUseCases, mock_content_repo: AsyncMock) -> None:
    content_id = uuid.uuid4()
    expected = {"id": str(content_id), "status": "visible"}
    mock_content_repo.get_managed = AsyncMock(return_value=expected)

    result = await use_cases.get_content(content_id)

    mock_content_repo.get_managed.assert_awaited_once_with(content_id)
    assert result == expected


@pytest.mark.asyncio
async def test_apply_content_action_invalid_action_raises(use_cases: AdminContentUseCases) -> None:
    with pytest.raises(ValueError, match="Unknown action_type"):
        await use_cases.apply_content_action(
            content_id=uuid.uuid4(),
            actor_admin_id=uuid.uuid4(),
            action_type="invalid_action",
            reason="Test",
            confirmed=False,
        )


@pytest.mark.asyncio
async def test_delete_permanently_calls_repo_and_audit(
    use_cases: AdminContentUseCases,
    mock_content_repo: AsyncMock,
    mock_audit: AsyncMock,
) -> None:
    content_id = uuid.uuid4()
    admin_id = uuid.uuid4()
    mock_content_repo.delete_permanently = AsyncMock(return_value=None)

    await use_cases.delete_permanently(
        content_id=content_id,
        actor_admin_id=admin_id,
        reason="Permanent removal",
    )

    mock_content_repo.delete_permanently.assert_awaited_once_with(content_id)
    mock_audit.record.assert_awaited_once()
