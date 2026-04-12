from backend.core.config import Settings


def test_settings_default_values():
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/test",
        secret_key="s3cret",
    )
    assert settings.debug is False
    assert settings.access_token_ttl_seconds == 900
    assert settings.refresh_token_ttl_days == 30
    assert settings.api_v1_prefix == "/v1"


def test_settings_secret_not_in_repr():
    settings = Settings(
        _env_file=None,
        database_url="postgresql+asyncpg://x:x@localhost/test",
        secret_key="super-secret",
    )
    r = repr(settings)
    assert "super-secret" not in r


def test_settings_from_env(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://a:b@localhost/db")
    monkeypatch.setenv("SECRET_KEY", "env-secret")
    monkeypatch.setenv("DEBUG", "true")
    monkeypatch.setenv("ACCESS_TOKEN_TTL_SECONDS", "600")
    monkeypatch.setenv("REFRESH_TOKEN_TTL_DAYS", "7")

    settings = Settings(_env_file=None)
    assert settings.database_url == "postgresql+asyncpg://a:b@localhost/db"
    assert settings.debug is True
    assert settings.access_token_ttl_seconds == 600
    assert settings.refresh_token_ttl_days == 7


def test_settings_extra_ignored(monkeypatch):
    monkeypatch.setenv("DATABASE_URL", "postgresql+asyncpg://x:x@localhost/test")
    monkeypatch.setenv("SECRET_KEY", "s")
    monkeypatch.setenv("SOME_RANDOM_VAR", "ignored")
    settings = Settings(_env_file=None)
    assert not hasattr(settings, "some_random_var")
