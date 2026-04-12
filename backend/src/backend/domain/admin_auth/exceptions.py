"""Admin auth domain exceptions."""


class AdminAuthError(Exception):
    """Base class for admin auth errors."""


class AdminInvalidCredentials(AdminAuthError):
    """Raised when email or password is wrong (unified to prevent enumeration)."""


class AdminAccountDisabled(AdminAuthError):
    """Raised when the admin account exists but is_active=False."""


class AdminAccountNotFound(AdminAuthError):
    """Raised when no admin account matches the given id."""


class AdminTokenExpired(AdminAuthError):
    """Raised when an admin session token has expired."""


class AdminTokenRevoked(AdminAuthError):
    """Raised when an admin session token has been revoked (e.g. after logout)."""
