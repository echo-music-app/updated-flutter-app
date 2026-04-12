import base64
import hashlib
import secrets

import bcrypt


def generate_token() -> tuple[str, bytes]:
    """Generate a new opaque token.

    Returns:
        Tuple of (base64url-encoded raw token string, SHA-256 hash bytes).
    """
    raw_bytes = secrets.token_bytes(64)
    raw_string = base64.urlsafe_b64encode(raw_bytes).decode("ascii")
    token_hash = hash_token(raw_string)
    return raw_string, token_hash


def hash_token(raw: str) -> bytes:
    """Return the SHA-256 hash of a raw token string."""
    return hashlib.sha256(raw.encode("ascii")).digest()


def hash_password(plain: str) -> str:
    """Hash a password using bcrypt."""
    salt = bcrypt.gensalt()
    return bcrypt.hashpw(plain.encode("utf-8"), salt).decode("utf-8")


def verify_password(plain: str, hashed: str) -> bool:
    """Verify a password against a bcrypt hash."""
    return bcrypt.checkpw(plain.encode("utf-8"), hashed.encode("utf-8"))


def generate_verification_code() -> str:
    """Return a six-digit email verification code."""
    return f"{secrets.randbelow(1_000_000):06d}"
