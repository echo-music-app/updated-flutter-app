# Implementation Plan: GitHub Actions CI/CD

**Branch**: `002-github-actions-ci-cd` | **Date**: 2026-02-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-github-actions-ci-cd/spec.md`

## Summary

Set up two GitHub Actions workflows: (1) a CI workflow that runs linting, formatting checks, and pytest (with a
PostgreSQL service container) on every push and pull request; (2) a CD workflow that builds a Docker image of the
backend and publishes it to GitHub Container Registry on every merge to `main`. A `backend/Dockerfile` will be created
following the uv multi-stage build pattern.

## Technical Context

**Language/Version**: Python 3.13 (backend); YAML (GitHub Actions workflows)
**Primary Dependencies**: `astral-sh/setup-uv@v7`, `docker/build-push-action@v6`, `docker/metadata-action@v5`,
`docker/login-action@v3`, `docker/setup-buildx-action@v3`, `actions/checkout@v6`
**Storage**: PostgreSQL 17 (service container for tests only; N/A for production image)
**Testing**: pytest + pytest-cov (existing); ruff, black, isort for lint/format checks
**Target Platform**: GitHub Actions (ubuntu-latest runners); Docker image for Linux/amd64
**Project Type**: CI/CD infrastructure (YAML workflows + Dockerfile)
**Performance Goals**: CI completes in <5 min; Docker build with GHA layer cache <3 min
**Constraints**: No external secrets; `GITHUB_TOKEN` only for registry auth; uv must be used (not pip)
**Scale/Scope**: Single monorepo, backend service only; no multi-arch builds

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate                                | Status  | Notes                                                               |
|-------------------------------------|---------|---------------------------------------------------------------------|
| Linting & Formatting enforced in CI | ✅ PASS  | CI workflow runs ruff, black --check, isort --check                 |
| Test suite runs in CI               | ✅ PASS  | pytest with coverage, PostgreSQL service container                  |
| Backend coverage ≥ 80%              | ✅ PASS  | Existing `fail_under = 100` in pyproject.toml; CI inherits this     |
| No secrets hardcoded                | ✅ PASS  | Registry auth uses `GITHUB_TOKEN` only                              |
| uv used (not pip)                   | ✅ PASS  | `astral-sh/setup-uv` + `uv sync --locked --dev`                     |
| Security scan                       | ⚠️ NOTE | No secret scanner step added in this feature; out of scope per spec |

*Post-design re-check*: All gates still pass. No new violations introduced.

## Project Structure

### Documentation (this feature)

```text
specs/002-github-actions-ci-cd/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # N/A (no data model changes)
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
.github/
└── workflows/
    ├── ci.yml           # Lint + test on every push/PR [NEW]
    └── cd.yml           # Docker build + push to ghcr.io on main [NEW]
backend/
└── Dockerfile           # Multi-stage uv build [NEW]
```

No existing files are modified. No data model changes.

## Phase 0: Research

Research is complete. See [research.md](./research.md) for full decision log.

**Key decisions**:

- uv caching via `astral-sh/setup-uv@v7` with `enable-cache: true`
- PostgreSQL 17 service container with `pg_isready` health check
- ghcr.io registry with `GITHUB_TOKEN` (no external secrets)
- Multi-stage Dockerfile: `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` builder → `python:3.13-slim-bookworm` runtime
- OCI labels via `docker/metadata-action@v5`; tags: `:latest` + `:sha-<short-sha>`
- Docker layer cache via `type=gha` (requires `setup-buildx-action`)
- CI uses raw tool commands (`ruff check .`, `black --check .`, `isort --check-only .`, `pytest`) because uv scripts are
  not yet defined in `pyproject.toml`

## Phase 1: Design & Contracts

### Data Model

No new data models. This feature adds infrastructure only.

### Contracts / Interfaces

This feature adds no new API endpoints or public interfaces. The Docker image is the deployment artifact; its interface
is the existing FastAPI application.

**Image naming contract**:

- Registry: `ghcr.io`
- Image: `ghcr.io/<github-org-or-user>/echo` (derived from `github.repository`)
- Tags: `:latest`, `:sha-<7-char-sha>`
- Entrypoint: `uvicorn backend.main:app --host 0.0.0.0 --port 8000`
- Exposed port: `8000`

### CI Workflow Design (`.github/workflows/ci.yml`)

```yaml
name: CI

on:
  push:
  pull_request:
    branches: [ main ]

jobs:
  lint:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    steps:
      - uses: actions/checkout@v6
      - uses: astral-sh/setup-uv@v7
        with:
          version: "0.6.x"
          enable-cache: true
          python-version: "3.13"
      - run: uv sync --locked --dev
      - run: uv run ruff check .
      - run: uv run black --check .
      - run: uv run isort --check-only .

  test:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: backend
    services:
      postgres:
        image: postgres:17
        env:
          POSTGRES_USER: echo
          POSTGRES_PASSWORD: echo
          POSTGRES_DB: echo_test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v6
      - uses: astral-sh/setup-uv@v7
        with:
          version: "0.6.x"
          enable-cache: true
          python-version: "3.13"
      - run: uv sync --locked --dev
      - name: Run tests
        env:
          DATABASE_URL: postgresql+asyncpg://echo:echo@localhost:5432/echo_test
          SECRET_KEY: ci-secret-key-not-used-in-tests
        run: uv run pytest --cov --cov-report=term-missing
```

### CD Workflow Design (`.github/workflows/cd.yml`)

```yaml
name: CD

on:
  push:
    branches: [ main ]

permissions:
  contents: read
  packages: write

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - uses: docker/setup-buildx-action@v3

      - uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Docker metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          flavor: |
            latest=true
          tags: |
            type=sha,prefix=sha-,format=short

      - uses: docker/build-push-action@v6
        with:
          context: ./backend
          file: ./backend/Dockerfile
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Dockerfile Design (`backend/Dockerfile`)

Multi-stage pattern from Astral's official uv-docker-example:

```dockerfile
# ---- builder ----
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_DEV=1 \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install third-party dependencies (cached layer, invalidated only on uv.lock change)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy source and install project
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# ---- runtime ----
FROM python:3.13-slim-bookworm

RUN groupadd --system --gid 999 appuser \
 && useradd --system --gid 999 --uid 999 --no-create-home appuser

COPY --from=builder --chown=appuser:appuser /app /app

ENV PATH="/app/.venv/bin:$PATH"

USER appuser
WORKDIR /app

EXPOSE 8000
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

**Note on `SECRET_KEY` in tests**: The existing `Settings` model requires `secret_key` and `database_url`. Tests may
need these as env vars even if not used in test logic. CI sets a dummy value.

## Complexity Tracking

| Concern                        | Deviation                     | Justification                                              |
|--------------------------------|-------------------------------|------------------------------------------------------------|
| No secret scanner in CI        | Missing constitution gate     | Out of scope per spec; tracked for future feature          |
| 100% test coverage enforcement | Inherited from pyproject.toml | `fail_under = 100` applies; CI will fail if coverage drops |

## Implementation Order

1. `backend/Dockerfile` — enables local `docker build` verification
2. `.github/workflows/ci.yml` — core quality gate
3. `.github/workflows/cd.yml` — image publication on main

No blocking dependencies between files; all can be implemented in a single PR.
