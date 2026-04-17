import asyncio
import os
from pathlib import Path

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import async_engine_from_config

# Import Base and all model modules so autogenerate detects every table
from backend.infrastructure.persistence.models.base import Base
import backend.infrastructure.persistence.models.user  # noqa: F401
import backend.infrastructure.persistence.models.friend  # noqa: F401
import backend.infrastructure.persistence.models.post  # noqa: F401
import backend.infrastructure.persistence.models.post_interaction  # noqa: F401
import backend.infrastructure.persistence.models.attachment  # noqa: F401
import backend.infrastructure.persistence.models.message  # noqa: F401
import backend.infrastructure.persistence.models.auth  # noqa: F401
import backend.infrastructure.persistence.models.spotify_credentials  # noqa: F401

target_metadata = Base.metadata

config = context.config


def _database_url_from_dotenv() -> str | None:
    dotenv_path = Path(__file__).resolve().parents[1] / ".env"
    if not dotenv_path.exists():
        return None
    for raw_line in dotenv_path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if key.strip() == "DATABASE_URL":
            return value.strip().strip('"').strip("'")
    return None


# Override sqlalchemy.url from environment variable if set
database_url = os.environ.get("DATABASE_URL")
if not database_url:
    database_url = _database_url_from_dotenv()
if database_url:
    config.set_main_option("sqlalchemy.url", database_url)


def run_migrations_offline() -> None:
    url = config.get_main_option("sqlalchemy.url")
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def do_run_migrations(connection):
    context.configure(
        connection=connection,
        target_metadata=target_metadata,
        compare_type=True,
        compare_server_default=True,
    )
    with context.begin_transaction():
        context.run_migrations()


async def run_migrations_online() -> None:
    connectable = async_engine_from_config(
        config.get_section(config.config_ini_section, {}),
        prefix="sqlalchemy.",
        poolclass=pool.NullPool,
    )
    async with connectable.connect() as connection:
        await connection.run_sync(do_run_migrations)
    await connectable.dispose()


if context.is_offline_mode():
    run_migrations_offline()
else:
    asyncio.run(run_migrations_online())
