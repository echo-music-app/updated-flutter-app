"""Admin authentication use cases."""

from datetime import UTC, datetime, timedelta

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.core.security import generate_token, verify_password
from backend.domain.admin_auth.entities import (
    AdminPermissionScope,
    AdminSessionInfo,
    AdminStatus,
)
from backend.domain.admin_auth.exceptions import (
    AdminAccountDisabled,
    AdminInvalidCredentials,
)
from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)
from backend.infrastructure.persistence.repositories.admin_auth_token_repository import (
    AdminAuthTokenRepository,
)
from backend.infrastructure.persistence.repositories.admin_repository import (
    AdminAccountRepository,
)

_TOKEN_TTL_HOURS = 8


class AdminAuthUseCases:
    def __init__(
        self,
        admin_repo: AdminAccountRepository,
        token_repo: AdminAuthTokenRepository,
        audit: AdminAuditUseCase,
    ) -> None:
        self._admin_repo = admin_repo
        self._token_repo = token_repo
        self._audit = audit

    async def login(self, *, email: str, password: str) -> AdminSessionInfo:
        """Validate credentials and issue an admin session token.

        Raises:
            AdminInvalidCredentials: email not found or password wrong.
            AdminAccountDisabled: account is_active=False.
        """
        admin = await self._admin_repo.get_by_email(email)

        if admin is None or not verify_password(password, admin.password_hash):
            if admin is not None:
                await self._audit.record(
                    actor_admin_id=admin.id,
                    entity_type=AdminEntityType.auth,
                    entity_id=None,
                    operation_name="admin_login",
                    outcome=AdminActionOutcome.denied,
                    change_payload={},
                )
            raise AdminInvalidCredentials("Invalid email or password")

        if not admin.is_active:
            await self._audit.record(
                actor_admin_id=admin.id,
                entity_type=AdminEntityType.auth,
                entity_id=None,
                operation_name="admin_login",
                outcome=AdminActionOutcome.denied,
                change_payload={},
            )
            raise AdminAccountDisabled("Admin account is disabled")

        raw_token, token_hash = generate_token()
        now = datetime.now(UTC)
        expires_at = now + timedelta(hours=_TOKEN_TTL_HOURS)

        await self._token_repo.create(
            admin_id=admin.id,
            token_hash=token_hash,
            expires_at=expires_at,
            created_at=now,
        )

        await self._audit.record(
            actor_admin_id=admin.id,
            entity_type=AdminEntityType.auth,
            entity_id=admin.id,
            operation_name="admin_login",
            outcome=AdminActionOutcome.success,
            change_payload={},
        )

        return AdminSessionInfo(
            admin_id=admin.id,
            email=admin.email,
            display_name=admin.display_name,
            status=AdminStatus.active,
            permission_scope=AdminPermissionScope(admin.permission_scope.value),
            authenticated_at=now,
            access_token=raw_token,
        )

    async def get_session(self, *, admin_id, email: str, display_name: str) -> AdminSessionInfo:
        """Return current session info from resolved admin (no DB query needed)."""
        return AdminSessionInfo(
            admin_id=admin_id,
            email=email,
            display_name=display_name,
            status=AdminStatus.active,
            permission_scope=AdminPermissionScope.full_admin,
            authenticated_at=datetime.now(UTC),
            access_token="",
        )

    async def logout(self, *, token_hash: bytes) -> None:
        """Revoke the current admin session token."""
        await self._token_repo.revoke(token_hash=token_hash)
        # Audit is emitted by the endpoint handler after this call returns.
