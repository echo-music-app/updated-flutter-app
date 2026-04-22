from dataclasses import dataclass


@dataclass
class TokenPair:
    access_token: str
    refresh_token: str
    expires_in: int


@dataclass
class RegistrationResult:
    verification_required: bool
    verification_expires_in: int
    verification_code: str | None = None


@dataclass
class VerificationDispatch:
    verification_required: bool
    verification_expires_in: int
    verification_code: str | None = None


@dataclass
class AppleIdentity:
    subject: str
    email: str
    email_verified: bool
    name: str | None = None


@dataclass
class SoundCloudIdentity:
    subject: str
    email: str
    name: str | None = None
