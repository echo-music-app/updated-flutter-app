# Research: GitHub Actions CI/CD

**Feature**: 002-github-actions-ci-cd
**Date**: 2026-02-28

## Decision Log

### uv Dependency Caching

**Decision**: Use `astral-sh/setup-uv@v7` with `enable-cache: true` and `python-version: "3.13"`.
**Rationale**: Official Astral action; handles uv cache keying on `uv.lock` automatically; eliminates need for a separate `actions/setup-python` step; runs `uv cache prune --ci` post-job to keep cache compact.
**Alternatives considered**: Manual `actions/cache` — redundant given the action's built-in caching.

```yaml
- uses: astral-sh/setup-uv@v7
  with:
    version: "0.6.x"
    enable-cache: true
    python-version: "3.13"
- run: uv sync --locked --dev
  working-directory: backend
```

### PostgreSQL Service Container

**Decision**: Use `postgres:17` service container with `pg_isready` health check and port mapping `5432:5432`.
**Rationale**: `pg_isready` is bundled in the official postgres image. Health check with retries prevents test failures caused by postgres not being ready. Connection via `localhost` because steps run on runner (not inside container).
**Alternatives considered**: None — this is the standard GitHub Actions pattern.

```yaml
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
```

Tests receive the URL via environment variable:
```yaml
env:
  DATABASE_URL: postgresql+asyncpg://echo:echo@localhost:5432/echo_test
```

### Docker Image Registry

**Decision**: GitHub Container Registry (`ghcr.io`) authenticated with `GITHUB_TOKEN`.
**Rationale**: No external secrets or registry accounts needed; scoped to the workflow run; free for public repositories; image name auto-derived from `github.repository`.
**Alternatives considered**: Docker Hub — requires external secret; AWS ECR — overkill for this project.

### Image Tagging Strategy

**Decision**: `docker/metadata-action@v5` with `flavor: latest=true` + `type=sha,prefix=sha-,format=short`.
**Rationale**: Auto-generates OCI labels from git context; produces `:latest` and `:sha-<short-sha>` without manual tag construction; satisfies the spec requirements exactly.

### Docker Layer Caching

**Decision**: `type=gha` cache on both `cache-from` and `cache-to` via `docker/build-push-action@v6`.
**Rationale**: Reuses Docker layer cache across workflow runs in GitHub Actions; requires `docker/setup-buildx-action@v3` (which enables BuildKit). Significantly speeds up image builds after the first run.

### Dockerfile Pattern

**Decision**: Multi-stage build using `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` as builder and `python:3.13-slim-bookworm` as runtime.
**Rationale**: Official Astral pattern for uv in Docker. Two-pass `uv sync` (deps only first, then project) maximises Docker layer cache. BuildKit mount caches keep uv package cache out of image layers. Non-root user for security.
**Alternatives considered**: Single-stage build — larger image; leaks uv toolchain into production.

### App Entry Point

**Decision**: `backend.main:app` (module `backend`, not `src.backend`).
**Rationale**: `uv sync --locked` installs the project package using the name declared in `pyproject.toml` (`name = "backend"`), so the importable name is `backend`, not `src.backend`.

### Workflow Structure

**Decision**: Two separate workflow files: `ci.yml` (lint + test) and `cd.yml` (Docker build + push).
**Rationale**: Separation of concerns; CI runs on every push/PR while CD only runs on main. Separate files also enable different permissions (`packages: write` only where needed).

### Lint/Format Commands

From `pyproject.toml`, the project defines these scripts via `uv run`:
- `uv run lint` → ruff check
- `uv run format` → black + isort

The CI job will use `uv run lint` and separate `uv run black --check .` + `uv run isort --check-only .` steps to differentiate failure reasons. Alternatively, a single `uv run format --check` if the script supports it. Need to verify the `format` script definition — if it only formats (not checks), the CI should call black/isort with `--check` directly.
