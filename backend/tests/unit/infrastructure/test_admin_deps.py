"""Unit tests for admin dependency wiring."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest
from fastapi import HTTPException

from backend.core.admin_deps import deny_message_access, get_current_admin


@pytest.mark.asyncio
async def test_get_current_admin_raises_401_without_token() -> None:
    """Missing Authorization header raises 401."""
    mock_request = MagicMock()
    mock_request.headers = {}
    mock_db = AsyncMock()

    with pytest.raises(HTTPException) as exc_info:
        await get_current_admin(request=mock_request, db=mock_db)

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_get_current_admin_raises_401_for_invalid_token() -> None:
    """A token that doesn't match any admin session raises 401."""
    mock_request = MagicMock()
    mock_request.headers = {"Authorization": "Bearer invalidtoken"}
    mock_db = AsyncMock()
    mock_db.execute = AsyncMock(return_value=MagicMock(scalar_one_or_none=MagicMock(return_value=None)))

    with pytest.raises(HTTPException) as exc_info:
        await get_current_admin(request=mock_request, db=mock_db)

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_get_current_admin_raises_403_for_inactive_admin() -> None:
    """A valid token for a disabled admin account raises 403."""
    mock_request = MagicMock()
    mock_request.headers = {"Authorization": "Bearer validtoken"}
    mock_db = AsyncMock()

    mock_token = MagicMock()
    mock_token.admin_id = uuid.uuid4()

    mock_admin = MagicMock()
    mock_admin.is_active = False

    token_result = MagicMock()
    token_result.scalar_one_or_none = MagicMock(return_value=mock_token)

    admin_result = MagicMock()
    admin_result.scalar_one_or_none = MagicMock(return_value=mock_admin)

    mock_db.execute = AsyncMock(side_effect=[token_result, admin_result])

    with pytest.raises(HTTPException) as exc_info:
        await get_current_admin(request=mock_request, db=mock_db)

    assert exc_info.value.status_code == 403


@pytest.mark.asyncio
async def test_get_current_admin_raises_401_when_admin_not_found() -> None:
    """A valid token that has no associated admin account raises 401."""
    mock_request = MagicMock()
    mock_request.headers = {"Authorization": "Bearer validtoken"}
    mock_db = AsyncMock()

    mock_token = MagicMock()
    mock_token.admin_id = uuid.uuid4()

    token_result = MagicMock()
    token_result.scalar_one_or_none = MagicMock(return_value=mock_token)

    admin_result = MagicMock()
    admin_result.scalar_one_or_none = MagicMock(return_value=None)

    mock_db.execute = AsyncMock(side_effect=[token_result, admin_result])

    with pytest.raises(HTTPException) as exc_info:
        await get_current_admin(request=mock_request, db=mock_db)

    assert exc_info.value.status_code == 401


@pytest.mark.asyncio
async def test_deny_message_access_always_raises_403() -> None:
    """deny_message_access always raises 403 after recording an audit entry."""
    mock_admin = MagicMock()
    mock_admin.id = uuid.uuid4()

    mock_db = AsyncMock()
    mock_action = MagicMock()
    mock_action.id = uuid.uuid4()
    mock_db.flush = AsyncMock()
    mock_db.refresh = AsyncMock()

    # Simulate the audit record creation — flush + refresh on the added action
    mock_db.add = MagicMock()

    async def fake_flush():
        pass

    async def fake_refresh(obj):
        obj.id = uuid.uuid4()

    mock_db.flush = AsyncMock(side_effect=fake_flush)
    mock_db.refresh = AsyncMock(side_effect=fake_refresh)

    with pytest.raises(HTTPException) as exc_info:
        await deny_message_access(admin=mock_admin, db=mock_db)

    assert exc_info.value.status_code == 403
    assert "message" in exc_info.value.detail.lower() or "not available" in exc_info.value.detail.lower()
