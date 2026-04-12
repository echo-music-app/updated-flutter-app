"""Unit tests for admin audit use case."""

import uuid
from unittest.mock import AsyncMock

import pytest

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.infrastructure.persistence.models.admin_action import AdminActionOutcome, AdminEntityType


@pytest.fixture
def mock_action_repo() -> AsyncMock:
    repo = AsyncMock()
    repo.create = AsyncMock()
    return repo


@pytest.fixture
def audit_use_case(mock_action_repo: AsyncMock) -> AdminAuditUseCase:
    return AdminAuditUseCase(action_repo=mock_action_repo)


@pytest.mark.asyncio
async def test_record_success_emits_action(
    audit_use_case: AdminAuditUseCase,
    mock_action_repo: AsyncMock,
) -> None:
    """A successful operation produces an AdminAction with outcome=success."""
    admin_id = uuid.uuid4()
    target_id = uuid.uuid4()

    await audit_use_case.record(
        actor_admin_id=admin_id,
        entity_type=AdminEntityType.user,
        entity_id=target_id,
        operation_name="user_status_change",
        outcome=AdminActionOutcome.success,
        change_payload={"old": "active", "new": "suspended"},
    )

    mock_action_repo.create.assert_awaited_once()
    call_kwargs = mock_action_repo.create.call_args.kwargs
    assert call_kwargs["outcome"] == AdminActionOutcome.success
    assert call_kwargs["actor_admin_id"] == admin_id


@pytest.mark.asyncio
async def test_record_denied_uses_empty_payload(
    audit_use_case: AdminAuditUseCase,
    mock_action_repo: AsyncMock,
) -> None:
    """Denied operations use an empty change_payload."""
    await audit_use_case.record(
        actor_admin_id=uuid.uuid4(),
        entity_type=AdminEntityType.message_access_denial,
        entity_id=None,
        operation_name="access_messages",
        outcome=AdminActionOutcome.denied,
        change_payload={},
    )

    call_kwargs = mock_action_repo.create.call_args.kwargs
    assert call_kwargs["outcome"] == AdminActionOutcome.denied
    assert call_kwargs["change_payload"] == {}


@pytest.mark.asyncio
async def test_record_auth_failure_with_no_entity_id(
    audit_use_case: AdminAuditUseCase,
    mock_action_repo: AsyncMock,
) -> None:
    """Auth failure events may have a null entity_id."""
    await audit_use_case.record(
        actor_admin_id=uuid.uuid4(),
        entity_type=AdminEntityType.auth,
        entity_id=None,
        operation_name="admin_login_denied",
        outcome=AdminActionOutcome.denied,
        change_payload={},
    )

    call_kwargs = mock_action_repo.create.call_args.kwargs
    assert call_kwargs["entity_id"] is None
    assert call_kwargs["entity_type"] == AdminEntityType.auth
