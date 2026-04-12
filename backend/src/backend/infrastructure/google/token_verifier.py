import asyncio

from google.auth.transport.requests import Request
from google.oauth2 import id_token

from backend.core.config import Settings
from backend.domain.auth.entities import GoogleIdentity
from backend.domain.auth.exceptions import GoogleAuthNotConfiguredError, InvalidGoogleTokenError

_VALID_ISSUERS = {"accounts.google.com", "https://accounts.google.com"}


async def verify_google_id_token(settings: Settings, raw_id_token: str) -> GoogleIdentity:
    if not settings.google_client_ids:
        raise GoogleAuthNotConfiguredError("Google authentication is not configured")

    try:
        payload = await asyncio.to_thread(id_token.verify_oauth2_token, raw_id_token, Request())
    except Exception as exc:  # pragma: no cover
        raise InvalidGoogleTokenError("Could not verify Google ID token") from exc

    audience = payload.get("aud")
    if audience not in settings.google_client_ids:
        raise InvalidGoogleTokenError("Google token audience is not allowed")

    issuer = payload.get("iss")
    if issuer not in _VALID_ISSUERS:
        raise InvalidGoogleTokenError("Google token issuer is invalid")

    subject = payload.get("sub")
    email = payload.get("email")
    if not subject or not email:
        raise InvalidGoogleTokenError("Google token is missing identity claims")

    email_verified = payload.get("email_verified") is True or payload.get("email_verified") == "true"

    return GoogleIdentity(
        subject=str(subject),
        email=str(email).strip().lower(),
        email_verified=email_verified,
        name=(str(payload["name"]).strip() if payload.get("name") else None),
    )
