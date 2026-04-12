"""Admin authentication endpoints."""

from datetime import UTC, datetime

from fastapi import APIRouter, Depends, HTTPException, Request
from pydantic import BaseModel, EmailStr
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.use_cases.admin_audit import AdminAuditUseCase
from backend.application.use_cases.admin_auth import AdminAuthUseCases
from backend.core.admin_deps import get_current_admin
from backend.core.database import get_db_session
from backend.core.security import hash_token
from backend.domain.admin_auth.exceptions import (
    AdminAccountDisabled,
    AdminInvalidCredentials,
)
from backend.infrastructure.persistence.models.admin import AdminAccount
from backend.infrastructure.persistence.models.admin_action import (
    AdminActionOutcome,
    AdminEntityType,
)
from backend.infrastructure.persistence.repositories.admin_action_repository import (
    AdminActionRepository,
)
from backend.infrastructure.persistence.repositories.admin_auth_token_repository import (
    AdminAuthTokenRepository,
)
from backend.infrastructure.persistence.repositories.admin_repository import (
    AdminAccountRepository,
)

router = APIRouter(prefix="/auth", tags=["admin-auth"])


class AdminLoginRequest(BaseModel):
    email: EmailStr
    password: str


class AdminSessionResponse(BaseModel):
    admin_id: str
    email: str
    display_name: str
    status: str
    permission_scope: str
    authenticated_at: str
    access_token: str = ""


def _get_use_cases(db: AsyncSession = Depends(get_db_session)) -> AdminAuthUseCases:
    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)
    return AdminAuthUseCases(
        admin_repo=AdminAccountRepository(db),
        token_repo=AdminAuthTokenRepository(db),
        audit=audit,
    )


@router.post("/login", response_model=AdminSessionResponse)
async def admin_login(
    body: AdminLoginRequest,
    use_cases: AdminAuthUseCases = Depends(_get_use_cases),
) -> AdminSessionResponse:
    """Authenticate an admin and issue a session token."""
    try:
        session = await use_cases.login(email=body.email, password=body.password)
    except AdminAccountDisabled as exc:
        raise HTTPException(status_code=403, detail="Admin account is disabled") from exc
    except AdminInvalidCredentials as exc:
        raise HTTPException(status_code=401, detail="Invalid credentials") from exc

    return AdminSessionResponse(
        admin_id=str(session.admin_id),
        email=session.email,
        display_name=session.display_name,
        status=session.status.value,
        permission_scope=session.permission_scope.value,
        authenticated_at=session.authenticated_at.isoformat(),
        access_token=session.access_token,
    )


@router.get("/session", response_model=AdminSessionResponse)
async def get_admin_session(
    admin: AdminAccount = Depends(get_current_admin),
) -> AdminSessionResponse:
    """Return the current admin session info."""
    return AdminSessionResponse(
        admin_id=str(admin.id),
        email=admin.email,
        display_name=admin.display_name,
        status="active" if admin.is_active else "disabled",
        permission_scope=admin.permission_scope.value,
        authenticated_at=datetime.now(UTC).isoformat(),
    )


@router.post("/logout")
async def admin_logout(
    request: Request,
    admin: AdminAccount = Depends(get_current_admin),
    db: AsyncSession = Depends(get_db_session),
) -> dict:
    """Revoke the current admin session token."""
    token_repo = AdminAuthTokenRepository(db)
    action_repo = AdminActionRepository(db)
    audit = AdminAuditUseCase(action_repo=action_repo)

    # Extract and revoke token
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        raw_token = auth_header[7:]
        token_hash = hash_token(raw_token)
        await token_repo.revoke(token_hash=token_hash)

    await audit.record(
        actor_admin_id=admin.id,
        entity_type=AdminEntityType.auth,
        entity_id=admin.id,
        operation_name="admin_logout",
        outcome=AdminActionOutcome.success,
        change_payload={},
    )

    return {"message": "Logged out successfully"}
