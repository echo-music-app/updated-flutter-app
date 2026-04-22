import re

from fastapi import APIRouter, Depends, Header, HTTPException, Request, Response
from fastapi.security import OAuth2PasswordRequestForm
from pydantic import BaseModel, field_validator
from sqlalchemy.ext.asyncio import AsyncSession

from backend.application.auth.use_cases import AuthUseCases
from backend.core.config import get_settings
from backend.core.database import get_db_session
from backend.core.decorators import public_endpoint
from backend.core.deps import get_current_user
from backend.domain.auth.exceptions import (
    AccountDisabledError,
    AppleAccountConflictError,
    AppleAuthNotConfiguredError,
    EmailDeliveryFailedError,
    EmailDeliveryNotConfiguredError,
    EmailNotVerifiedError,
    EmailTakenError,
    InvalidAppleTokenError,
    InvalidCredentialsError,
    InvalidMfaCodeError,
    InvalidSoundCloudTokenError,
    InvalidTokenError,
    InvalidVerificationCodeError,
    MfaNotConfiguredError,
    MfaRequiredError,
    SoundCloudAccountConflictError,
    SoundCloudAuthNotConfiguredError,
    UsernameTakenError,
)
from backend.infrastructure.apple.token_verifier import verify_apple_id_token
from backend.infrastructure.email.smtp_sender import send_verification_email
from backend.infrastructure.persistence.models.user import User
from backend.infrastructure.persistence.repositories.token_repository import SqlAlchemyTokenRepository
from backend.infrastructure.persistence.repositories.user_repository import SqlAlchemyUserRepository
from backend.infrastructure.soundcloud.token_exchange import exchange_soundcloud_code_for_identity

router = APIRouter(prefix="/auth", tags=["auth"])
_PASSWORD_POLICY_ERROR = "Password must be 8-128 chars and include uppercase, lowercase, number, and special character"


class RegisterRequest(BaseModel):
    email: str
    username: str
    password: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
            raise ValueError("Invalid email format")
        if len(v) > 255:
            raise ValueError("Email must be at most 255 characters")
        return v

    @field_validator("username")
    @classmethod
    def validate_username(cls, v: str) -> str:
        if len(v) < 3 or len(v) > 50:
            raise ValueError("Username must be 3-50 characters")
        if not re.match(r"^[a-zA-Z0-9_.\-]+$", v):
            raise ValueError("Username can only contain alphanumeric characters, underscores, dots, and hyphens")
        return v

    @field_validator("password")
    @classmethod
    def validate_password(cls, v: str) -> str:
        if len(v) < 8:
            raise ValueError("Password must be at least 8 characters")
        if len(v) > 128:
            raise ValueError("Password must be at most 128 characters")
        if not re.search(r"[A-Z]", v):
            raise ValueError(_PASSWORD_POLICY_ERROR)
        if not re.search(r"[a-z]", v):
            raise ValueError(_PASSWORD_POLICY_ERROR)
        if not re.search(r"\d", v):
            raise ValueError(_PASSWORD_POLICY_ERROR)
        if not re.search(r'[!@#\$%^&*(),.?":{}|<>_\-+=/\\\[\]~`]', v):
            raise ValueError(_PASSWORD_POLICY_ERROR)
        return v


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    expires_in: int


class RegisterResponse(BaseModel):
    verification_required: bool
    verification_expires_in: int
    verification_code: str | None = None
    message: str


class VerifyEmailRequest(BaseModel):
    email: str
    code: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
            raise ValueError("Invalid email format")
        return v

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        code = v.strip()
        if not re.match(r"^\d{6}$", code):
            raise ValueError("Verification code must be 6 digits")
        return code


class ResendVerificationRequest(BaseModel):
    email: str

    @field_validator("email")
    @classmethod
    def validate_email(cls, v: str) -> str:
        if not re.match(r"^[^@\s]+@[^@\s]+\.[^@\s]+$", v):
            raise ValueError("Invalid email format")
        return v


class ResendVerificationResponse(BaseModel):
    verification_required: bool
    verification_expires_in: int
    verification_code: str | None = None
    message: str


class RefreshRequest(BaseModel):
    refresh_token: str


class MfaSetupResponse(BaseModel):
    secret: str
    otpauth_uri: str


class MfaCodeRequest(BaseModel):
    code: str

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        code = v.strip()
        if not re.match(r"^\d{6}$", code):
            raise ValueError("MFA code must be 6 digits")
        return code


class AppleLoginRequest(BaseModel):
    id_token: str

    @field_validator("id_token")
    @classmethod
    def validate_id_token(cls, v: str) -> str:
        token = v.strip()
        if not token:
            raise ValueError("Apple ID token is required")
        return token


class SoundCloudTokenRequest(BaseModel):
    code: str
    redirect_uri: str

    @field_validator("code")
    @classmethod
    def validate_code(cls, v: str) -> str:
        code = v.strip()
        if not code:
            raise ValueError("SoundCloud authorization code is required")
        return code

    @field_validator("redirect_uri")
    @classmethod
    def validate_redirect_uri(cls, v: str) -> str:
        redirect_uri = v.strip()
        if "://" not in redirect_uri:
            raise ValueError("redirect_uri must be an absolute URI")
        if redirect_uri.startswith("http://"):
            raise ValueError("redirect_uri must not use insecure HTTP")
        return redirect_uri


def get_auth_use_cases(db: AsyncSession = Depends(get_db_session)) -> AuthUseCases:
    return AuthUseCases(
        user_repo=SqlAlchemyUserRepository(db),
        token_repo=SqlAlchemyTokenRepository(db),
        settings=get_settings(),
    )


@router.post("/register", response_model=RegisterResponse, status_code=201)
@public_endpoint
async def register(body: RegisterRequest, use_cases: AuthUseCases = Depends(get_auth_use_cases)):
    settings = get_settings()
    try:
        result = await use_cases.register(body.email, body.username, body.password)
    except EmailTakenError:
        raise HTTPException(status_code=409, detail="Email already taken")
    except UsernameTakenError:
        raise HTTPException(status_code=409, detail="Username already taken")

    if result.verification_code is not None:
        if not settings.debug:
            try:
                await send_verification_email(settings, to_email=body.email, code=result.verification_code)
            except EmailDeliveryNotConfiguredError:
                raise HTTPException(status_code=503, detail="Email delivery is not configured")
            except EmailDeliveryFailedError:
                raise HTTPException(status_code=503, detail="Could not send verification email")

    return RegisterResponse(
        verification_required=result.verification_required,
        verification_expires_in=result.verification_expires_in,
        verification_code=result.verification_code if settings.debug else None,
        message="Check your email for the verification code.",
    )


@router.post("/login", response_model=TokenResponse)
@public_endpoint
async def login(
    form: OAuth2PasswordRequestForm = Depends(),
    mfa_code: str | None = Header(default=None, alias="X-MFA-Code"),
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    try:
        token_pair = await use_cases.login(form.username, form.password, mfa_code=mfa_code)
    except InvalidCredentialsError:
        raise HTTPException(status_code=401, detail="Invalid email or password")
    except EmailNotVerifiedError:
        raise HTTPException(status_code=403, detail="Email not verified")
    except AccountDisabledError:
        raise HTTPException(status_code=403, detail="Account is disabled")
    except MfaRequiredError:
        raise HTTPException(status_code=401, detail="MFA code required")
    except InvalidMfaCodeError:
        raise HTTPException(status_code=401, detail="Invalid MFA code")
    except MfaNotConfiguredError:
        raise HTTPException(status_code=400, detail="MFA is not configured")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/mfa/setup", response_model=MfaSetupResponse)
async def setup_mfa(
    current_user: User = Depends(get_current_user),
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    secret, otpauth_uri = await use_cases.setup_mfa(current_user.id)
    return MfaSetupResponse(secret=secret, otpauth_uri=otpauth_uri)


@router.post("/mfa/enable", status_code=204, response_class=Response)
async def enable_mfa(
    body: MfaCodeRequest,
    current_user: User = Depends(get_current_user),
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    try:
        await use_cases.enable_mfa(current_user.id, body.code)
    except MfaNotConfiguredError:
        raise HTTPException(status_code=400, detail="MFA setup was not started")
    except InvalidMfaCodeError:
        raise HTTPException(status_code=400, detail="Invalid MFA code")
    return Response(status_code=204)


@router.post("/mfa/disable", status_code=204, response_class=Response)
async def disable_mfa(
    body: MfaCodeRequest,
    current_user: User = Depends(get_current_user),
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    try:
        await use_cases.disable_mfa(current_user.id, body.code)
    except MfaNotConfiguredError:
        raise HTTPException(status_code=400, detail="MFA is not enabled")
    except InvalidMfaCodeError:
        raise HTTPException(status_code=400, detail="Invalid MFA code")
    return Response(status_code=204)


@router.post("/verify-email", response_model=TokenResponse)
@public_endpoint
async def verify_email(body: VerifyEmailRequest, use_cases: AuthUseCases = Depends(get_auth_use_cases)):
    return await _verify_email_and_issue_tokens(body, use_cases)


async def _verify_email_and_issue_tokens(body: VerifyEmailRequest, use_cases: AuthUseCases) -> TokenResponse:
    try:
        token_pair = await use_cases.verify_email(body.email, body.code)
    except InvalidVerificationCodeError:
        raise HTTPException(status_code=400, detail="Invalid or expired verification code")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/resend-verification", response_model=ResendVerificationResponse)
@public_endpoint
async def resend_verification(
    body: ResendVerificationRequest,
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    settings = get_settings()
    result = await use_cases.resend_verification_code(body.email)
    if result.verification_required and result.verification_code is not None and not settings.debug:
        try:
            await send_verification_email(settings, to_email=body.email, code=result.verification_code)
        except EmailDeliveryNotConfiguredError:
            raise HTTPException(status_code=503, detail="Email delivery is not configured")
        except EmailDeliveryFailedError:
            raise HTTPException(status_code=503, detail="Could not send verification email")

    return ResendVerificationResponse(
        verification_required=result.verification_required,
        verification_expires_in=result.verification_expires_in,
        verification_code=result.verification_code if settings.debug else None,
        message="If the account exists, a verification code has been issued.",
    )


@router.post("/apple", response_model=TokenResponse)
@public_endpoint
async def apple_login(
    body: AppleLoginRequest,
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    settings = get_settings()
    try:
        identity = await verify_apple_id_token(settings, body.id_token)
        token_pair = await use_cases.login_with_apple(identity)
    except AppleAuthNotConfiguredError:
        raise HTTPException(status_code=503, detail="Apple authentication is not configured")
    except InvalidAppleTokenError:
        raise HTTPException(status_code=401, detail="Invalid Apple token")
    except InvalidCredentialsError:
        raise HTTPException(status_code=401, detail="Apple account email is not verified")
    except AppleAccountConflictError:
        raise HTTPException(status_code=409, detail="This email is already linked to a different Apple account")
    except AccountDisabledError:
        raise HTTPException(status_code=403, detail="Account is disabled")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/soundcloud/token", response_model=TokenResponse)
@public_endpoint
async def soundcloud_token_login(
    body: SoundCloudTokenRequest,
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    settings = get_settings()
    try:
        identity = await exchange_soundcloud_code_for_identity(
            settings,
            code=body.code,
            redirect_uri=body.redirect_uri,
        )
        token_pair = await use_cases.login_with_soundcloud(identity)
    except SoundCloudAuthNotConfiguredError:
        raise HTTPException(status_code=503, detail="SoundCloud authentication is not configured")
    except InvalidSoundCloudTokenError:
        raise HTTPException(status_code=401, detail="Invalid SoundCloud token")
    except SoundCloudAccountConflictError:
        raise HTTPException(status_code=409, detail="This email is already linked to a different SoundCloud account")
    except AccountDisabledError:
        raise HTTPException(status_code=403, detail="Account is disabled")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/refresh-token", response_model=TokenResponse)
@public_endpoint
async def refresh_token(body: RefreshRequest, use_cases: AuthUseCases = Depends(get_auth_use_cases)):
    try:
        token_pair = await use_cases.refresh_token(body.refresh_token)
    except InvalidTokenError:
        raise HTTPException(status_code=401, detail="Invalid or expired refresh token")

    return TokenResponse(
        access_token=token_pair.access_token,
        refresh_token=token_pair.refresh_token,
        expires_in=token_pair.expires_in,
    )


@router.post("/logout", status_code=204, response_class=Response)
async def logout(
    request: Request,
    current_user: User = Depends(get_current_user),
    use_cases: AuthUseCases = Depends(get_auth_use_cases),
):
    access_token = request.state.access_token
    await use_cases.logout(current_user.id, access_token.id)
    return Response(status_code=204)
