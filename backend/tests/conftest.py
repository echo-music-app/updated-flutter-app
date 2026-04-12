import os

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine

import backend.infrastructure.persistence.models  # noqa: F401 — registers all models with Base.metadata
from backend.admin import create_admin_app
from backend.core.config import Settings
from backend.core.database import get_db_session
from backend.infrastructure.persistence.models.base import Base
from backend.main import create_app

DATABASE_URL = "postgresql+asyncpg://echo:echo@postgres:5432/echo_test"


_TEST_ENCRYPTION_KEY = "a" * 64


@pytest.fixture(scope="session", autouse=True)
def _configure_test_spotify_key():
    """Ensure get_settings() returns a valid 32-byte encryption key in all tests."""
    os.environ["SPOTIFY_TOKEN_ENCRYPTION_KEY"] = _TEST_ENCRYPTION_KEY
    from backend.core.config import get_settings

    get_settings.cache_clear()
    yield
    get_settings.cache_clear()


@pytest.fixture(scope="session")
def settings():
    return Settings(
        _env_file=None,
        database_url=DATABASE_URL,
        secret_key="test-secret-key",
        debug=True,
        spotify_token_encryption_key=_TEST_ENCRYPTION_KEY,
    )


@pytest.fixture
async def test_engine():
    engine = create_async_engine(DATABASE_URL, pool_pre_ping=True)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
        await conn.run_sync(Base.metadata.create_all)
    yield engine
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.drop_all)
    await engine.dispose()


@pytest.fixture
async def db_session(test_engine):
    async with test_engine.connect() as conn:
        transaction = await conn.begin()
        session_factory = async_sessionmaker(bind=conn, expire_on_commit=False)
        async with session_factory() as session:
            yield session
        await transaction.rollback()


@pytest.fixture
async def app(settings, db_session):
    application = create_app(settings)

    async def override_get_db_session():
        yield db_session

    application.dependency_overrides[get_db_session] = override_get_db_session
    try:
        yield application
    finally:
        application.dependency_overrides.clear()


@pytest.fixture
def app_no_db(settings):
    """App fixture without DB dependency override — for contract tests that don't need DB."""
    return create_app(settings)


@pytest.fixture
async def async_client(app):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://backend-dev") as client:
        yield client


@pytest.fixture
async def async_client_no_db(app_no_db):
    """Client for contract tests that don't need DB."""
    async with AsyncClient(transport=ASGITransport(app=app_no_db), base_url="http://backend-dev") as client:
        yield client


@pytest.fixture
async def admin_app(settings, db_session):
    application = create_admin_app(settings)

    async def override_get_db_session():
        yield db_session

    application.dependency_overrides[get_db_session] = override_get_db_session
    try:
        yield application
    finally:
        application.dependency_overrides.clear()


@pytest.fixture
def admin_app_no_db(settings):
    """Admin app fixture without DB dependency override — for contract tests."""
    return create_admin_app(settings)


@pytest.fixture
async def admin_async_client(admin_app):
    async with AsyncClient(transport=ASGITransport(app=admin_app), base_url="http://backend-dev") as client:
        yield client


@pytest.fixture
async def admin_async_client_no_db(admin_app_no_db):
    """Client for admin contract tests that don't need DB."""
    async with AsyncClient(transport=ASGITransport(app=admin_app_no_db), base_url="http://backend-dev") as client:
        yield client
