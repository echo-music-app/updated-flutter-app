"""Domain exception hierarchy for music search."""


class MusicSearchError(Exception):
    """Base exception for music search domain errors."""


class ProviderUnavailableError(MusicSearchError):
    """Raised when a music provider cannot be reached or returns an error."""

    def __init__(self, provider: str, reason: str) -> None:
        self.provider = provider
        self.reason = reason
        super().__init__(f"Provider '{provider}' unavailable: {reason}")


class ProviderAuthError(ProviderUnavailableError):
    """Raised when provider authentication fails (401/403)."""


class ProviderRateLimitError(ProviderUnavailableError):
    """Raised when provider rate limit is exceeded (429)."""


class AllProvidersUnavailableError(MusicSearchError):
    """Raised when all configured providers are unavailable."""

    def __init__(self, provider_errors: dict[str, str]) -> None:
        self.provider_errors = provider_errors
        providers = ", ".join(provider_errors.keys())
        super().__init__(f"All providers unavailable: {providers}")


class SearchValidationError(MusicSearchError):
    """Raised when the search request fails domain-level validation."""
