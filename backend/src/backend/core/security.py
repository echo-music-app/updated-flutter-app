import base64
import hashlib
import hmac
import secrets
import struct
import time

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


def generate_totp_secret() -> str:
    """Generate a Base32 TOTP secret suitable for authenticator apps."""
    raw = secrets.token_bytes(20)
    return base64.b32encode(raw).decode("ascii").rstrip("=")


def verify_totp_code(secret: str, code: str, *, step_seconds: int = 30, digits: int = 6, window: int = 1) -> bool:
    """Verify a TOTP code with a small time window for clock skew."""
    candidate = code.strip()
    if not candidate.isdigit() or len(candidate) != digits:
        return False

    now_counter = int(time.time() // step_seconds)
    for offset in range(-window, window + 1):
        if _totp_at_counter(secret, now_counter + offset, digits=digits) == candidate:
            return True
    return False


def _totp_at_counter(secret: str, counter: int, *, digits: int = 6) -> str:
    padded = secret.upper() + "=" * ((8 - len(secret) % 8) % 8)
    key = base64.b32decode(padded, casefold=True)
    msg = struct.pack(">Q", counter)
    digest = hmac.new(key, msg, hashlib.sha1).digest()
    offset = digest[-1] & 0x0F
    code_int = (struct.unpack(">I", digest[offset : offset + 4])[0] & 0x7FFFFFFF) % (10**digits)
    return str(code_int).zfill(digits)
