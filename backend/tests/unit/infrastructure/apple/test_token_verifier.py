import pytest

from backend.core.config import Settings
from backend.domain.auth.exceptions import AppleAuthNotConfiguredError, InvalidAppleTokenError
from backend.infrastructure.apple import token_verifier


@pytest.mark.anyio
async def test_verify_apple_id_token_requires_configured_client_ids():
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/test",
        secret_key="s3cret",
        apple_client_ids=[],
    )

    with pytest.raises(AppleAuthNotConfiguredError):
        await token_verifier.verify_apple_id_token(settings, "fake-token")


@pytest.mark.anyio
async def test_verify_apple_id_token_success(monkeypatch: pytest.MonkeyPatch):
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/test",
        secret_key="s3cret",
        apple_client_ids=["com.echo.app"],
    )

    class _FakeSigningKey:
        key = object()

    class _FakeJWKClient:
        def __init__(self, _url: str) -> None:
            pass

        def get_signing_key_from_jwt(self, _token: str) -> _FakeSigningKey:
            return _FakeSigningKey()

    def _fake_decode(
        _token: str,
        _key: object,
        *,
        algorithms: list[str],
        audience: list[str],
        issuer: str,
        options: dict[str, list[str]],
    ) -> dict[str, str]:
        assert algorithms == ["RS256"]
        assert audience == ["com.echo.app"]
        assert issuer == "https://appleid.apple.com"
        assert "sub" in options["require"]
        return {
            "sub": "apple-sub-123",
            "email": "appleuser@example.com",
            "email_verified": "true",
        }

    monkeypatch.setattr(token_verifier, "PyJWKClient", _FakeJWKClient)
    monkeypatch.setattr(token_verifier.jwt, "decode", _fake_decode)

    identity = await token_verifier.verify_apple_id_token(settings, "fake-token")
    assert identity.subject == "apple-sub-123"
    assert identity.email == "appleuser@example.com"
    assert identity.email_verified is True


@pytest.mark.anyio
async def test_verify_apple_id_token_requires_email_claim(monkeypatch: pytest.MonkeyPatch):
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/test",
        secret_key="s3cret",
        apple_client_ids=["com.echo.app"],
    )

    class _FakeSigningKey:
        key = object()

    class _FakeJWKClient:
        def __init__(self, _url: str) -> None:
            pass

        def get_signing_key_from_jwt(self, _token: str) -> _FakeSigningKey:
            return _FakeSigningKey()

    def _fake_decode(
        _token: str,
        _key: object,
        *,
        algorithms: list[str],
        audience: list[str],
        issuer: str,
        options: dict[str, list[str]],
    ) -> dict[str, str]:
        return {"sub": "apple-sub-123"}

    monkeypatch.setattr(token_verifier, "PyJWKClient", _FakeJWKClient)
    monkeypatch.setattr(token_verifier.jwt, "decode", _fake_decode)

    with pytest.raises(InvalidAppleTokenError):
        await token_verifier.verify_apple_id_token(settings, "fake-token")
