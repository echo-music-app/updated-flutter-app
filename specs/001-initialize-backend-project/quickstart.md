# Quickstart: Backend Development

**Applies to**: `backend/` sub-project
**Prerequisites**: Python 3.13+, `uv`, Podman + Podman Compose (for local PostgreSQL), `make`

---

## 1. One-time Setup

```bash
# From repo root
cd backend

# Verify Python version (should be 3.13.x)
uv python pin 3.13
uv python install 3.13   # if not already installed

# Install all dependencies (runtime + dev) from the lockfile
uv sync --dev
```

---

## 2. Start / Stop the Local Environment

Available Makefile targets (run from repo root):

| Target | Action |
|---|---|
| `make up` | Start all services (PostgreSQL) in the background |
| `make down` | Stop and remove containers (data volume preserved) |
| `make logs` | Tail container logs |

```bash
# From repo root
make up
```

This starts a rootless `postgres:18` container via Podman Compose on `localhost:5432`, running as the current user (`--userns=keep-id`) to avoid volume permission issues. Credentials come from `backend/.env`.

---

## 3. Configure Environment

```bash
# From backend/
cp .env.example .env
# Edit .env — at minimum set DATABASE_URL and SECRET_KEY
```

Minimal `.env`:
```dotenv
DATABASE_URL=postgresql+asyncpg://echo:echo@localhost:5432/echo
SECRET_KEY=change-me-in-production
DEBUG=true
```

---

## 4. Run Migrations

```bash
cd backend
uv run migrate
# Equivalent to: alembic upgrade head
```

---

## 5. Start the Dev Server

```bash
cd backend
uv run dev
# Equivalent to: uvicorn src.main:app --reload --host 0.0.0.0 --port 8000
```

API available at:
- `http://localhost:8000/v1/docs` — Swagger UI
- `http://localhost:8000/v1/openapi.json` — OpenAPI schema
- `http://localhost:8000/v1/health` — Health check

---

## 6. Run Tests

```bash
cd backend
uv run test
# Equivalent to: pytest tests/ -v --cov=src --cov-report=term-missing
```

Tests use a separate test database (configured in `tests/conftest.py`). The test DB is created and dropped per session.

**Coverage requirement**: 100% unit test coverage enforced (constitution § II). CI will fail below threshold.

---

## 7. Lint & Format

```bash
cd backend

# Check linting (zero errors required)
uv run lint
# Equivalent to: ruff check src/ tests/

# Format code
uv run format
# Equivalent to: black src/ tests/ && isort src/ tests/

# Check formatting without changes (for CI)
uv run python -m black --check src/ tests/
uv run python -m isort --check src/ tests/
```

---

## 8. Create a Migration

After modifying SQLAlchemy models:

```bash
cd backend
uv run alembic revision --autogenerate -m "describe_change_here"
# Review the generated file in migrations/versions/
uv run migrate
```

---

## 9. Project Structure

```text
backend/
├── pyproject.toml       # Dependencies, tool config, uv scripts
├── uv.lock              # Committed; do not edit manually
├── .env.example         # Committed env template
├── .env                 # NOT committed; local secrets
├── alembic.ini
├── migrations/
│   ├── env.py
│   └── versions/
│       └── 0001_initial_schema.py
├── src/
│   ├── main.py          # ASGI entrypoint (app = create_app())
│   ├── app.py           # create_app() factory + lifespan
│   ├── core/
│   │   ├── config.py    # Settings (pydantic-settings, lru_cache)
│   │   ├── database.py  # AsyncEngine + async_sessionmaker
│   │   ├── security.py  # Token generation (secrets), SHA-256 hashing
│   │   ├── deps.py      # get_db_session, get_current_user dependencies
│   │   └── decorators.py# @public_endpoint marker
│   ├── models/          # SQLAlchemy ORM models (see data-model.md)
│   ├── services/        # Business logic (populated by feature sprints)
│   └── api/
│       └── v1/
│           ├── health.py # GET /v1/health
│           └── auth.py   # POST /v1/auth/*
└── tests/
    ├── conftest.py       # Fixtures: async DB, test client
    ├── contract/
    │   └── test_auth_contract.py
    ├── integration/
    │   └── test_auth_integration.py
    └── unit/
        ├── test_security.py
        └── test_config.py
```

---

## 10. Dependency Management

```bash
# Add a runtime dependency
uv add <package>

# Add a dev-only dependency
uv add --dev <package>

# Update lockfile after pyproject.toml edits
uv lock

# Install from locked state (used by CI)
uv sync --frozen
```

**Never** use `pip install` directly — the constitution prohibits it.

---

## 11. Common Issues

| Problem | Solution |
|---|---|
| `asyncpg.exceptions.InvalidCatalogNameError: database "echo" does not exist` | Run `make up` and then `uv run migrate` |
| `ValidationError: database_url field required` | Copy `.env.example` to `.env` and fill in values |
| `MissingGreenlet` error in tests | Ensure `expire_on_commit=False` on `AsyncSessionLocal`; do not access ORM attributes outside an active session context |
| Port 5432 already in use | Change `POSTGRES_PORT` in `compose.yml` and update `DATABASE_URL` in `.env` |
| `coverage: FAIL Required test coverage of 100%` | Write the missing unit tests — see constitution § II |