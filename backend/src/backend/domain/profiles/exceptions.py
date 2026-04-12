"""Profile domain exceptions."""


class ProfileNotFoundError(Exception):
    """Raised when a requested user profile does not exist."""


class UsernameConflictError(Exception):
    """Raised when the desired username is already taken by another user."""


class InvalidProfilePatchError(Exception):
    """Raised when a PATCH /v1/me payload is invalid (empty, non-mutable fields, etc.)."""
