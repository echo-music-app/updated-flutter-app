import uuid
from datetime import datetime

import uuid6
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from backend.infrastructure.persistence.models.user import User, UserStatus


class SqlAlchemyUserRepository:
    def __init__(self, session: AsyncSession) -> None:
        self._session = session

    async def get_by_google_subject(self, google_subject: str) -> User | None:
        result = await self._session.execute(select(User).where(User.google_subject == google_subject))
        return result.scalar_one_or_none()

    async def get_by_email(self, email: str) -> User | None:
        result = await self._session.execute(select(User).where(User.email == email))
        return result.scalar_one_or_none()

    async def get_by_username(self, username: str) -> User | None:
        result = await self._session.execute(select(User).where(User.username == username))
        return result.scalar_one_or_none()

    async def get_by_id(self, user_id: uuid.UUID) -> User | None:
        result = await self._session.execute(select(User).where(User.id == user_id))
        return result.scalar_one_or_none()

    async def create(self, email: str, username: str, password_hash: str) -> User:
        user = User(
            id=uuid6.uuid7(),
            email=email,
            username=username,
            password_hash=password_hash,
            status=UserStatus.pending,
        )
        self._session.add(user)
        try:
            await self._session.flush()
        except IntegrityError:
            await self._session.rollback()
            raise
        return user

    async def set_email_verification(
        self,
        user_id: uuid.UUID,
        *,
        code_hash: bytes,
        expires_at: datetime,
        sent_at: datetime,
    ) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.email_verification_code_hash = code_hash
        user.email_verification_expires_at = expires_at
        user.email_verification_sent_at = sent_at
        user.email_verified_at = None
        return user

    async def mark_email_verified(self, user_id: uuid.UUID, *, verified_at: datetime) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.email_verified_at = verified_at
        user.email_verification_code_hash = None
        user.email_verification_expires_at = None
        user.email_verification_sent_at = verified_at
        user.status = UserStatus.active
        return user

    async def link_google_account(
        self,
        user_id: uuid.UUID,
        *,
        google_subject: str,
        verified_at: datetime,
    ) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.google_subject = google_subject
        user.email_verified_at = verified_at
        user.email_verification_code_hash = None
        user.email_verification_expires_at = None
        user.email_verification_sent_at = verified_at
        user.status = UserStatus.active
        return user

    async def set_mfa_secret(self, user_id: uuid.UUID, *, secret: str) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.mfa_totp_secret = secret
        user.mfa_enabled = False
        return user

    async def enable_mfa(self, user_id: uuid.UUID) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        if not user.mfa_totp_secret:
            return None
        user.mfa_enabled = True
        return user

    async def disable_mfa(self, user_id: uuid.UUID) -> User | None:
        user = await self.get_by_id(user_id)
        if user is None:
            return None
        user.mfa_enabled = False
        user.mfa_totp_secret = None
        return user
