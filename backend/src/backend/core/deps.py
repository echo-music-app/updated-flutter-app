from datetime import UTC, datetime

from fastapi import Depends, HTTPException, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from backend.core.database import get_db_session
from backend.core.security import hash_token
from backend.infrastructure.persistence.models.auth import AccessToken
from backend.infrastructure.persistence.models.user import User, UserStatus


async def get_current_user(
    request: Request,
    db: AsyncSession = Depends(get_db_session),
) -> User | None:
    endpoint = request.scope.get("endpoint")
    if endpoint and getattr(endpoint, "__public__", False):
        return None

    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing or invalid authorization header")

    raw_token = auth_header[7:]
    token_hash = hash_token(raw_token)

    result = await db.execute(
        select(AccessToken).where(
            AccessToken.token_hash == token_hash,
            AccessToken.expires_at > datetime.now(UTC),
            AccessToken.revoked_at.is_(None),
        )
    )
    access_token = result.scalar_one_or_none()
    if access_token is None:
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    user_result = await db.execute(select(User).where(User.id == access_token.user_id))
    user = user_result.scalar_one_or_none()
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    if user.email_verified_at is None:
        raise HTTPException(status_code=403, detail="Email not verified")

    if user.status == UserStatus.disabled:
        raise HTTPException(status_code=403, detail="Account is disabled")

    request.state.user = user
    request.state.access_token = access_token
    return user
