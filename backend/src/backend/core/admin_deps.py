"""Admin-specific FastAPI dependency wiring.

Dependency injection for admin authentication. Keeps all wiring in core/;
business logic lives in application/use_cases/.
"""

from datetime import UTC, datetime

from fastapi import Depends, HTTPException, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.database import get_db_session
from backend.core.security import hash_token
from backend.infrastructure.persistence.models.admin import AdminAccount
from backend.infrastructure.persistence.models.admin_auth import AdminAccessToken
from backend.infrastructure.persistence.models.auth import AccessToken

bearer_scheme = HTTPBearer(auto_error=False)


async def get_current_admin(
    request: Request,
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    db: AsyncSession = Depends(get_db_session),
) -> AdminAccount:
    """Resolve and validate the current admin from the request's Bearer token.

    Raises:
        HTTPException 401: Missing or invalid token.
        HTTPException 403: Valid token but admin account is inactive.
    """
    raw_token: str | None = None
    if isinstance(credentials, HTTPAuthorizationCredentials):
        if credentials.scheme.lower() == "bearer":
            raw_token = credentials.credentials
    else:
        auth_header = request.headers.get("Authorization", "")
        scheme, _, token = auth_header.partition(" ")
        if scheme.lower() == "bearer" and token.strip():
            raw_token = token.strip()

    if raw_token is None:
        raise HTTPException(
            status_code=401,
            detail="Missing or invalid authorization header",
        )

    token_hash = hash_token(raw_token)

    result = await db.execute(
        select(AdminAccessToken).where(
            AdminAccessToken.token_hash == token_hash,
            AdminAccessToken.expires_at > datetime.now(UTC),
            AdminAccessToken.revoked_at.is_(None),
        )
    )
    access_token = result.scalar_one_or_none()
    if access_token is None:
        # Check if this is a valid user token presented on an admin route
        user_token_result = await db.execute(select(AccessToken).where(AccessToken.token_hash == token_hash))
        if user_token_result.scalar_one_or_none() is not None:
            raise HTTPException(status_code=403, detail="User tokens are not permitted on admin routes")
        raise HTTPException(status_code=401, detail="Invalid or expired admin token")

    admin_result = await db.execute(select(AdminAccount).where(AdminAccount.id == access_token.admin_id))
    admin = admin_result.scalar_one_or_none()
    if admin is None:
        raise HTTPException(status_code=401, detail="Admin account not found")

    if not admin.is_active:
        raise HTTPException(status_code=403, detail="Admin account is disabled")

    request.state.admin = admin
    request.state.admin_access_token = access_token
    return admin


async def deny_message_access(
    admin: AdminAccount = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db_session),
) -> None:
    """Dependency that always denies access and audits the attempt.

    Attach to any route that must be blocked for message access.
    """
    from backend.application.use_cases.admin_audit import AdminAuditUseCase
    from backend.infrastructure.persistence.models.admin_action import (
        AdminActionOutcome,
        AdminEntityType,
    )
    from backend.infrastructure.persistence.repositories.admin_action_repository import (
        AdminActionRepository,
    )

    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)
    await audit.record(
        actor_admin_id=admin.id,
        entity_type=AdminEntityType.message_access_denial,
        entity_id=None,
        operation_name="message_access_denied",
        outcome=AdminActionOutcome.denied,
        change_payload={},
    )
    raise HTTPException(status_code=403, detail="Message management is not available in the admin workspace")
