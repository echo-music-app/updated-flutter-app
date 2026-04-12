"""Unit tests for admin auth use cases."""

import uuid
from unittest.mock import AsyncMock, MagicMock

import pytest

from backend.application.use_cases.admin_auth import AdminAuthUseCases
from backend.domain.admin_auth.exceptions import (
    AdminAccountDisabled,
    AdminInvalidCredentials,
)


@pytest.fixture
def mock_admin_repo() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def mock_token_repo() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def mock_audit() -> AsyncMock:
    return AsyncMock()


@pytest.fixture
def auth_use_cases(mock_admin_repo, mock_token_repo, mock_audit) -> AdminAuthUseCases:
    return AdminAuthUseCases(
        admin_repo=mock_admin_repo,
        token_repo=mock_token_repo,
        audit=mock_audit,
    )


@pytest.mark.asyncio
async def test_login_with_valid_credentials_returns_token(
    auth_use_cases: AdminAuthUseCases,
    mock_admin_repo: AsyncMock,
    mock_token_repo: AsyncMock,
) -> None:
    """Correct credentials for an active admin return a token."""
    mock_admin = MagicMock()
    mock_admin.id = uuid.uuid4()
    mock_admin.is_active = True
    mock_admin.email = "admin@example.com"
    mock_admin.permission_scope.value = "full_admin"
    mock_admin_repo.get_by_email = AsyncMock(return_value=mock_admin)

    mock_token = MagicMock()
    mock_token.raw_token = "rawtoken123"
    mock_token_repo.create = AsyncMock(return_value=mock_token)

    import backend.application.use_cases.admin_auth as module

    original = module.verify_password
    module.verify_password = MagicMock(return_value=True)

    result = await auth_use_cases.login(email="admin@example.com", password="correct_password")

    module.verify_password = original

    assert result is not None


@pytest.mark.asyncio
async def test_login_with_wrong_password_raises(
    auth_use_cases: AdminAuthUseCases,
    mock_admin_repo: AsyncMock,
) -> None:
    """Wrong password raises AdminInvalidCredentials."""
    mock_admin = MagicMock()
    mock_admin.is_active = True
    mock_admin_repo.get_by_email = AsyncMock(return_value=mock_admin)

    import backend.application.use_cases.admin_auth as module

    original = module.verify_password
    module.verify_password = MagicMock(return_value=False)

    with pytest.raises(AdminInvalidCredentials):
        await auth_use_cases.login(email="admin@example.com", password="wrong")

    module.verify_password = original


@pytest.mark.asyncio
async def test_login_unknown_email_raises(
    auth_use_cases: AdminAuthUseCases,
    mock_admin_repo: AsyncMock,
) -> None:
    """Unknown email raises AdminInvalidCredentials (not NotFound, to avoid enumeration)."""
    mock_admin_repo.get_by_email = AsyncMock(return_value=None)

    with pytest.raises(AdminInvalidCredentials):
        await auth_use_cases.login(email="nobody@example.com", password="password")


@pytest.mark.asyncio
async def test_login_disabled_admin_raises(
    auth_use_cases: AdminAuthUseCases,
    mock_admin_repo: AsyncMock,
) -> None:
    """Disabled admin raises AdminAccountDisabled."""
    import backend.application.use_cases.admin_auth as module

    original = module.verify_password
    module.verify_password = MagicMock(return_value=True)

    mock_admin = MagicMock()
    mock_admin.is_active = False
    mock_admin_repo.get_by_email = AsyncMock(return_value=mock_admin)

    with pytest.raises(AdminAccountDisabled):
        await auth_use_cases.login(email="admin@example.com", password="password")

    module.verify_password = original


@pytest.mark.asyncio
async def test_get_session_returns_admin_session_info(auth_use_cases: AdminAuthUseCases) -> None:
    """get_session returns an AdminSessionInfo populated from the provided arguments."""
    from backend.domain.admin_auth.entities import AdminSessionInfo

    admin_id = uuid.uuid4()
    result = await auth_use_cases.get_session(
        admin_id=admin_id,
        email="admin@example.com",
        display_name="Test Admin",
    )

    assert isinstance(result, AdminSessionInfo)
    assert result.admin_id == admin_id
    assert result.email == "admin@example.com"
    assert result.display_name == "Test Admin"
    assert result.access_token == ""


@pytest.mark.asyncio
async def test_logout_calls_token_repo_revoke(
    auth_use_cases: AdminAuthUseCases,
    mock_token_repo: AsyncMock,
) -> None:
    """logout delegates to token_repo.revoke with the supplied token_hash."""
    token_hash = b"fake_token_hash_bytes"
    mock_token_repo.revoke = AsyncMock(return_value=None)

    await auth_use_cases.logout(token_hash=token_hash)

    mock_token_repo.revoke.assert_awaited_once_with(token_hash=token_hash)
