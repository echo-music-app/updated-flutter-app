"""Unit tests for admin friend relationship use cases."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.application.use_cases.admin_friend_relationships import AdminFriendRelationshipsUseCases


@pytest.fixture
def mock_repo() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def mock_audit() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def use_cases(mock_repo, mock_audit) -> AdminFriendRelationshipsUseCases:
    return AdminFriendRelationshipsUseCases(relationship_repo=mock_repo, audit=mock_audit)


@pytest.mark.asyncio
async def test_list_relationships_returns_projections(use_cases: AdminFriendRelationshipsUseCases, mock_repo: AsyncMock) -> None:
    mock_repo.list_managed = AsyncMock(return_value=[])
    result = await use_cases.list_relationships(page=1, page_size=20)
    assert isinstance(result, list)


@pytest.mark.asyncio
async def test_remove_relationship_records_audit(
    use_cases: AdminFriendRelationshipsUseCases,
    mock_repo: AsyncMock,
    mock_audit: AsyncMock,
) -> None:
    rel_id = uuid.uuid4()
    admin_id = uuid.uuid4()
    mock_repo.get_managed = AsyncMock(return_value={"id": str(rel_id), "status": "active"})
    mock_repo.apply_action = AsyncMock(return_value={"id": str(rel_id), "status": "removed"})

    await use_cases.apply_action(
        relationship_id=rel_id,
        actor_admin_id=admin_id,
        action_type="remove",
        reason="Policy cleanup",
        confirmed=False,
    )

    mock_audit.record.assert_awaited_once()


@pytest.mark.asyncio
async def test_permanent_delete_requires_confirmation(
    use_cases: AdminFriendRelationshipsUseCases,
    mock_repo: AsyncMock,
) -> None:
    mock_repo.get_managed = AsyncMock(return_value=MagicMock())

    with pytest.raises(ValueError, match="confirmation"):
        await use_cases.apply_action(
            relationship_id=uuid.uuid4(),
            actor_admin_id=uuid.uuid4(),
            action_type="delete_permanently",
            reason="Test",
            confirmed=False,
        )


@pytest.mark.asyncio
async def test_get_relationship_returns_projection(use_cases: AdminFriendRelationshipsUseCases, mock_repo: AsyncMock) -> None:
    rel_id = uuid.uuid4()
    expected = {"id": str(rel_id), "status": "active"}
    mock_repo.get_managed = AsyncMock(return_value=expected)

    result = await use_cases.get_relationship(rel_id)

    mock_repo.get_managed.assert_awaited_once_with(rel_id)
    assert result == expected


@pytest.mark.asyncio
async def test_apply_action_invalid_action_type_raises(use_cases: AdminFriendRelationshipsUseCases) -> None:
    with pytest.raises(ValueError, match="Unknown action_type"):
        await use_cases.apply_action(
            relationship_id=uuid.uuid4(),
            actor_admin_id=uuid.uuid4(),
            action_type="invalid_action",
            reason="Test",
            confirmed=False,
        )


def test_friend_relationship_record_instantiation() -> None:
    from backend.domain.admin_friend_relationships.entities import FriendRelationshipRecord, RelationshipStatus

    record = FriendRelationshipRecord(
        id=uuid.uuid4(),
        user_a_id=uuid.uuid4(),
        user_b_id=uuid.uuid4(),
        status=RelationshipStatus.active,
        created_at="2026-01-01T00:00:00",
        updated_at="2026-01-01T00:00:00",
    )
    assert record.status == RelationshipStatus.active


def test_relationship_status_enum_values() -> None:
    from backend.domain.admin_friend_relationships.entities import RelationshipStatus

    assert RelationshipStatus.pending == "pending"
    assert RelationshipStatus.active == "active"
    assert RelationshipStatus.blocked == "blocked"
    assert RelationshipStatus.removed == "removed"
