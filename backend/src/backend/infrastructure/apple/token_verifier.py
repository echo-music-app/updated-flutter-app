import asyncio

import jwt
from jwt import PyJWKClient

from backend.core.config import Settings
from backend.domain.auth.entities import AppleIdentity
from backend.domain.auth.exceptions import AppleAuthNotConfiguredError, InvalidAppleTokenError

_APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys"
_APPLE_ISSUER = "https://appleid.apple.com"
_APPLE_ALGORITHMS = ["RS256"]


async def verify_apple_id_token(settings: Settings, raw_id_token: str) -> AppleIdentity:
    if not settings.apple_client_ids:
        raise AppleAuthNotConfiguredError("Apple authentication is not configured")

    jwk_client = PyJWKClient(_APPLE_JWKS_URL)
    try:
        signing_key = await asyncio.to_thread(jwk_client.get_signing_key_from_jwt, raw_id_token)
        payload = await asyncio.to_thread(
            jwt.decode,
            raw_id_token,
            signing_key.key,
            algorithms=_APPLE_ALGORITHMS,
            audience=settings.apple_client_ids,
            issuer=_APPLE_ISSUER,
            options={"require": ["iss", "aud", "exp", "iat", "sub"]},
        )
    except Exception as exc:  # pragma: no cover
        raise InvalidAppleTokenError("Could not verify Apple ID token") from exc

    subject = payload.get("sub")
    email = payload.get("email")
    if not subject or not email:
        raise InvalidAppleTokenError("Apple token is missing identity claims")

    email_verified = payload.get("email_verified") is True or payload.get("email_verified") == "true"

    return AppleIdentity(
        subject=str(subject),
        email=str(email).strip().lower(),
        email_verified=email_verified,
        name=(str(payload["name"]).strip() if payload.get("name") else None),
    )
