import re
import uuid
from datetime import UTC, datetime, timedelta

from sqlalchemy.exc import IntegrityError

from backend.core.config import Settings
from backend.core.security import (
    generate_token,
    generate_totp_secret,
    generate_verification_code,
    hash_password,
    hash_token,
    verify_password,
    verify_totp_code,
)
from backend.domain.auth.entities import GoogleIdentity, RegistrationResult, TokenPair, VerificationDispatch
from backend.domain.auth.exceptions import (
    AccountDisabledError,
    EmailNotVerifiedError,
    EmailTakenError,
    GoogleAccountConflictError,
    InvalidCredentialsError,
    InvalidMfaCodeError,
    InvalidTokenError,
    InvalidVerificationCodeError,
    MfaNotConfiguredError,
    MfaRequiredError,
    UsernameTakenError,
)
from backend.domain.auth.repositories import ITokenRepository, IUserRepository


class AuthUseCases:
    def __init__(
        self,
        user_repo: IUserRepository,
        token_repo: ITokenRepository,
        settings: Settings,
    ) -> None:
        self._user_repo = user_repo
        self._token_repo = token_repo
        self._settings = settings

    async def register(self, email: str, username: str, password: str) -> RegistrationResult:
        now = datetime.now(UTC)
        try:
            user = await self._user_repo.create(email, username, hash_password(password))
        except IntegrityError as e:
            error_str = str(e.orig)
            if "email" in error_str:
                raise EmailTakenError("Email already taken") from e
            if "username" in error_str:
                raise UsernameTakenError("Username already taken") from e
            raise  # pragma: no cover

        dispatch = await self._dispatch_verification_code(user.id, now=now)
        return RegistrationResult(
            verification_required=dispatch.verification_required,
            verification_expires_in=dispatch.verification_expires_in,
            verification_code=dispatch.verification_code,
        )

    async def login(self, email: str, password: str, mfa_code: str | None = None) -> TokenPair:
        user = await self._user_repo.get_by_email(email)
        if user is None or not verify_password(password, user.password_hash):
            raise InvalidCredentialsError("Invalid email or password")
        if user.email_verified_at is None:
            raise EmailNotVerifiedError("Email not verified")
        if str(user.status) == "disabled":
            raise AccountDisabledError("Account is disabled")
        if getattr(user, "mfa_enabled", False):
            secret = getattr(user, "mfa_totp_secret", None)
            if not secret:
                raise MfaNotConfiguredError("MFA is enabled but not configured")
            if not mfa_code:
                raise MfaRequiredError("MFA code required")
            if not verify_totp_code(secret, mfa_code):
                raise InvalidMfaCodeError("Invalid MFA code")

        return await self._issue_tokens(user.id, datetime.now(UTC))

    async def setup_mfa(self, user_id: uuid.UUID) -> tuple[str, str]:
        user = await self._user_repo.get_by_id(user_id)
        if user is None:
            raise InvalidCredentialsError("Invalid user")

        secret = generate_totp_secret()
        await self._user_repo.set_mfa_secret(user_id, secret=secret)
        issuer = self._settings.app_name.replace(":", "").strip() or "Echo"
        account = user.email
        otpauth_uri = f"otpauth://totp/{issuer}:{account}?secret={secret}&issuer={issuer}&digits=6&period=30"
        return secret, otpauth_uri

    async def enable_mfa(self, user_id: uuid.UUID, code: str) -> None:
        user = await self._user_repo.get_by_id(user_id)
        if user is None or not user.mfa_totp_secret:
            raise MfaNotConfiguredError("MFA setup was not started")
        if not verify_totp_code(user.mfa_totp_secret, code):
            raise InvalidMfaCodeError("Invalid MFA code")
        await self._user_repo.enable_mfa(user_id)

    async def disable_mfa(self, user_id: uuid.UUID, code: str) -> None:
        user = await self._user_repo.get_by_id(user_id)
        if user is None or not user.mfa_enabled or not user.mfa_totp_secret:
            raise MfaNotConfiguredError("MFA is not enabled")
        if not verify_totp_code(user.mfa_totp_secret, code):
            raise InvalidMfaCodeError("Invalid MFA code")
        await self._user_repo.disable_mfa(user_id)

    async def login_with_google(self, identity: GoogleIdentity) -> TokenPair:
        if not identity.email_verified:
            raise InvalidCredentialsError("Google account email is not verified")

        now = datetime.now(UTC)
        user = await self._user_repo.get_by_google_subject(identity.subject)
        if user is None:
            user = await self._user_repo.get_by_email(identity.email)
            if user is not None:
                if user.google_subject not in (None, identity.subject):
                    raise GoogleAccountConflictError("This email is already linked to a different Google account")
                await self._ensure_account_enabled(user)
                linked_user = await self._user_repo.link_google_account(
                    user.id,
                    google_subject=identity.subject,
                    verified_at=now,
                )
                if linked_user is not None:
                    user = linked_user
            else:
                username = await self._generate_available_username(identity.email)
                user = await self._user_repo.create(
                    identity.email,
                    username,
                    hash_password(str(uuid.uuid4())),
                )
                linked_user = await self._user_repo.link_google_account(
                    user.id,
                    google_subject=identity.subject,
                    verified_at=now,
                )
                if linked_user is not None:
                    user = linked_user

        await self._ensure_account_enabled(user)
        return await self._issue_tokens(user.id, now)

    async def verify_email(self, email: str, code: str) -> TokenPair:
        user = await self._user_repo.get_by_email(email)
        if user is None:
            raise InvalidVerificationCodeError("Invalid or expired verification code")
        if user.email_verified_at is not None:
            raise InvalidVerificationCodeError("Invalid or expired verification code")

        expected_hash = user.email_verification_code_hash
        expires_at = user.email_verification_expires_at
        now = datetime.now(UTC)
        if expected_hash is None or expires_at is None or expires_at < now:
            raise InvalidVerificationCodeError("Invalid or expired verification code")
        if hash_token(code) != expected_hash:
            raise InvalidVerificationCodeError("Invalid or expired verification code")

        await self._user_repo.mark_email_verified(user.id, verified_at=now)
        return await self._issue_tokens(user.id, now)

    async def resend_verification_code(self, email: str) -> VerificationDispatch:
        user = await self._user_repo.get_by_email(email)
        now = datetime.now(UTC)
        if user is None:
            return VerificationDispatch(
                verification_required=True,
                verification_expires_in=self._settings.email_verification_code_ttl_seconds,
            )
        if user.email_verified_at is not None:
            return VerificationDispatch(verification_required=False, verification_expires_in=0)
        return await self._dispatch_verification_code(user.id, now=now)

    async def refresh_token(self, raw_refresh_token: str) -> TokenPair:
        from backend.core.security import hash_token

        now = datetime.now(UTC)
        token_hash = hash_token(raw_refresh_token)
        old_refresh = await self._token_repo.get_refresh_by_hash(token_hash)

        if old_refresh is None:
            raise InvalidTokenError("Token not found")
        if old_refresh.expires_at < now:
            raise InvalidTokenError("Token expired")
        if old_refresh.rotated_at is not None:
            raise InvalidTokenError("Token already rotated")
        if old_refresh.revoked_at is not None:
            raise InvalidTokenError("Token revoked")

        await self._token_repo.rotate_refresh(old_refresh.id, now)
        if old_refresh.access_token_id:
            await self._token_repo.revoke_access(old_refresh.access_token_id, now)

        return await self._issue_tokens(old_refresh.user_id, now)

    async def logout(self, user_id: uuid.UUID, access_token_id: uuid.UUID) -> None:
        now = datetime.now(UTC)
        await self._token_repo.revoke_access(access_token_id, now)
        await self._token_repo.revoke_refresh_tokens_for_access(user_id, access_token_id, now)

    async def _issue_tokens(self, user_id: uuid.UUID, now: datetime) -> TokenPair:
        access_raw, access_hash = generate_token()
        refresh_raw, refresh_hash = generate_token()

        access_token = await self._token_repo.create_access_token(
            user_id=user_id,
            token_hash=access_hash,
            expires_at=now + timedelta(seconds=self._settings.access_token_ttl_seconds),
        )
        await self._token_repo.create_refresh_token(
            user_id=user_id,
            token_hash=refresh_hash,
            access_token_id=access_token.id,
            expires_at=now + timedelta(days=self._settings.refresh_token_ttl_days),
        )

        return TokenPair(
            access_token=access_raw,
            refresh_token=refresh_raw,
            expires_in=self._settings.access_token_ttl_seconds,
        )

    async def _dispatch_verification_code(self, user_id: uuid.UUID, *, now: datetime) -> VerificationDispatch:
        code = generate_verification_code()
        await self._user_repo.set_email_verification(
            user_id,
            code_hash=hash_token(code),
            expires_at=now + timedelta(seconds=self._settings.email_verification_code_ttl_seconds),
            sent_at=now,
        )
        return VerificationDispatch(
            verification_required=True,
            verification_expires_in=self._settings.email_verification_code_ttl_seconds,
            verification_code=code,
        )

    async def _generate_available_username(self, email: str) -> str:
        base = re.sub(r"[^a-zA-Z0-9_.-]+", "", email.split("@", 1)[0].lower()) or "echo-user"
        base = base[:50]
        candidate = base
        suffix = 1
        while await self._user_repo.get_by_username(candidate) is not None:
            suffix_text = str(suffix)
            trimmed_base = base[: max(1, 50 - len(suffix_text) - 1)]
            candidate = f"{trimmed_base}-{suffix_text}"
            suffix += 1
        return candidate

    async def _ensure_account_enabled(self, user: object) -> None:
        if str(getattr(user, "status", "")) == "disabled":
            raise AccountDisabledError("Account is disabled")
