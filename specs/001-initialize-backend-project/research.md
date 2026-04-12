# Research: Initialize Backend Project

**Branch**: `001-initialize-backend-project` | **Date**: 2026-02-25
**Status**: All NEEDS CLARIFICATION resolved — ready for Phase 1 design

---

## 1. PostgreSQL Async Driver

**Decision**: `asyncpg` via `postgresql+asyncpg://` dialect string.

**Rationale**:
- Implements the PostgreSQL wire protocol natively; no blocking libpq calls on the event loop.
- SQLAlchemy 2.0 shipped its `AsyncEngine`/`AsyncSession` story with asyncpg as the primary reference implementation — the dialect is the most exercised by the SQLAlchemy core team.
- Full support for PostgreSQL native types: UUID, arrays, JSONB, TIMESTAMPTZ — all present in the Echo domain model.

**Alternatives considered**:
- `psycopg3-async` — correct SQLAlchemy integration but less production mileage on the asyncio path through mid-2025.
- `aiopg` — wraps libpq, older, not actively developed; no community traction.
- Synchronous `psycopg2` with thread-pool — blocks the event loop; violates the p95 latency targets.

---

## 2. Opaque Token Storage

**Decision**: Two separate tables — `access_tokens` and `refresh_tokens` — storing the SHA-256 hash of the token, never the raw value.

**Token generation**: 32 random bytes from `secrets.token_bytes(32)`, base64url-encoded for wire transfer; SHA-256 hash (32 bytes, `BYTEA`) stored in DB.

**Token lifetimes**: access = 15 minutes, refresh = 30 days.

**Revocation**: synchronous column update (`revoked_at = now()`) as required by constitution § VI. All tokens for a user's session are invalidated on logout in a single UPDATE.

**Cleanup**: expired + revoked rows purged by a scheduled background job (out of scope for init sprint). Partial index `WHERE revoked_at IS NULL` on `expires_at` keeps the cleanup worker efficient.

**Rationale**:
- Two tables over one: access and refresh tokens have different lifecycles, revocation semantics, and security properties; mixing them under a `token_type` discriminator complicates index design.
- Hash storage: a leaked DB dump cannot be used directly to impersonate users. SHA-256 is sufficient for high-entropy random tokens (no bcrypt needed — bcrypt at 100-300ms/lookup would destroy p95 targets).
- Lookup hot path: `SELECT ... WHERE token_hash = $1` → single index seek on `UNIQUE BYTEA`, sub-millisecond even at high concurrency.

**Alternatives considered**:
- Single `tokens` table with discriminator — mixed concerns, wider scans.
- Store raw token — catastrophic on DB breach; rejected.
- Redis-only — no durable audit record; loses state on Redis restart.
- JWT — explicitly prohibited by the constitution.

---

## 3. Application Configuration (pydantic-settings v2)

**Decision**: Single `Settings(BaseSettings)` class in `backend/src/core/config.py` with `SettingsConfigDict`, `lru_cache` singleton, `SecretStr` for credentials, `PostgresDsn` for the database URL.

**Key choices**:
- `SettingsConfigDict` (not inner `Config` class) — type-checkable, pydantic v2 idiomatic.
- `lru_cache` — `.env` parsed exactly once; same object returned on every `Depends(get_settings)` call.
- `SecretStr` — prevents secret values appearing in `repr()` or logs.
- `extra="ignore"` — allows Docker-level env vars (e.g., `POSTGRES_PASSWORD`) without `ValidationError`.
- `field_validator` on `database_url` — normalises `postgres://` / `postgresql://` to `postgresql+asyncpg://`.

**Alternatives considered**: plain `os.environ` (no type validation), pydantic v1 `BaseSettings` (unavailable in v2), multiple settings classes (fragmented, harder to test), `dynaconf` (heavyweight non-pydantic DSL).

---

## 4. FastAPI App Factory Pattern

**Decision**: `create_app()` factory function + `@asynccontextmanager lifespan` (no deprecated `@app.on_event`).

**Key choices**:
- `create_app()` separates construction from the module-level singleton — essential for test isolation (each test can call `create_app()` with overridden settings).
- `lifespan` context manager: `engine.dispose()` in shutdown path cleanly closes all DB connections.
- `engine.dispose()` is the only startup/shutdown action needed for SQLAlchemy; the connection pool warms lazily on first request.

**Alternatives considered**: `@app.on_event` decorators (deprecated since FastAPI 0.95, will be removed), module-level singleton (import-time side effects, untestable), third-party app factories (unnecessary abstraction).

---

## 5. Async Session Management in FastAPI

**Decision**: Module-level `async_sessionmaker`, request-scoped `get_db_session` dependency that yields an `AsyncSession`, commits on success and rolls back on exception.

**Key choices**:
- `expire_on_commit=False` — avoids lazy-load `MissingGreenlet` errors when accessing ORM objects after commit (required in async context).
- `pool_pre_ping=True` — detects stale connections (firewall idle timeout, DB restart) transparently.
- `pool_size=10, max_overflow=20` — sensible defaults, configurable via `Settings`.
- Dependency owns the transaction boundary — route handlers never call `commit()` or `rollback()` directly.

**Alternatives considered**: global `AsyncSession` singleton (identity map corruption across concurrent requests), `async_scoped_session` (adds complexity without benefit here), sync `sessionmaker` (legacy path, type-checker warnings).

---

## 6. Alembic + SQLAlchemy Async (`env.py`)

**Decision**: `async_engine_from_config` + `connection.run_sync(do_run_migrations)` + `NullPool`, `asyncio.run()` at module level. `compare_type=True` and `compare_server_default=True` enabled.

**Key choices**:
- Alembic migration ops are synchronous; `run_sync` provides a sync `Connection` proxy — the canonical Alembic async pattern.
- `NullPool` for migration engine — one-shot scripts don't need pooling.
- Separate migration engine from the application's `src.core.database.engine` — keeps migrations runnable without full pydantic settings initialization.
- `DATABASE_URL` env var overrides `alembic.ini` at runtime.

**Alternatives considered**: sync `psycopg2` for migrations only (second driver dependency, inconsistent), use application engine directly (couples to pydantic settings), fully async migration ops (no native async Alembic API; raises `MissingGreenlet`).

---

## 7. uv Commands

**Decision**: `uv` as exclusive dependency/venv manager per constitution mandate.

**Key commands**:
```bash
# Initialise sub-project
uv init backend --package
cd backend && uv python pin 3.13

# Add runtime deps
uv add "fastapi[standard]" "sqlalchemy[asyncio]" asyncpg alembic pydantic-settings python-multipart

# Add dev deps
uv add --dev pytest pytest-asyncio anyio httpx pytest-cov black ruff isort mypy "sqlalchemy[mypy]"

# Run
uv run dev        # start dev server (via [tool.uv.scripts])
uv run test       # run test suite
uv run migrate    # alembic upgrade head

# Lock / sync
uv lock           # regenerate uv.lock (commit this)
uv sync --frozen  # CI: fail if uv.lock is stale
```

**Key choices**:
- `fastapi[standard]` pulls uvicorn[standard] (uvloop + httptools), python-multipart, email-validator.
- `sqlalchemy[asyncio]` installs greenlet, required for SQLAlchemy's async bridge layer.
- `uv sync --frozen` in CI — fails if `uv.lock` is out of sync; enforces the constitution's lockfile commitment requirement.
- No `requirements.txt` — prohibited by the constitution.

---

## 8. Development Environment

**Decision**: Podman Compose for local PostgreSQL; containers run as current user (`--userns=keep-id`) to prevent volume permission issues; Makefile wraps `podman compose` commands; `.env` file loaded by pydantic-settings; `.env.example` committed; `.env` in `.gitignore`.

**compose.yml** provides:
- `postgres:18` container on port 5432
- Named volume for data persistence

**Alternatives considered**: local PostgreSQL installation (varies by developer OS, setup overhead), SQLite for dev (async SQLite driver exists but schema divergence from production is a risk).

---

## Summary

| Topic | Decision |
|---|---|
| Async PG driver | `asyncpg` |
| Token storage | 2 tables (`access_tokens`, `refresh_tokens`), SHA-256 `BYTEA` hash, synchronous revocation |
| Config | `pydantic-settings` v2, `lru_cache`, `SecretStr` |
| App factory | `create_app()` + `lifespan` context manager |
| Session DI | `async_sessionmaker`, request-scoped dependency, `expire_on_commit=False` |
| Alembic | `async_engine_from_config` + `run_sync` + `NullPool` |
| uv | `uv add`, `uv run`, `uv sync --frozen` in CI |
| Dev DB | Podman Compose (`postgres:18`), rootless, current-user UID mapping |