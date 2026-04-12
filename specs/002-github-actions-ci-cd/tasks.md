# Tasks: GitHub Actions CI/CD

**Input**: Design documents from `/specs/002-github-actions-ci-cd/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths included in all descriptions

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the directory structure and shared infrastructure for CI/CD workflows.

- [x] T001 Create `.github/workflows/` directory structure in the repository root

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `backend/Dockerfile` must exist before the CD workflow can build an image. It is also independently testable via `docker build`.

- [x] T002 Create multi-stage `backend/Dockerfile` using `ghcr.io/astral-sh/uv:python3.13-bookworm-slim` as builder and `python:3.13-slim-bookworm` as runtime, with `UV_COMPILE_BYTECODE=1`, `UV_LINK_MODE=copy`, `UV_NO_DEV=1`, two-pass `uv sync --locked`, non-root `appuser` (uid/gid 999), `ENV PATH="/app/.venv/bin:$PATH"`, `EXPOSE 8000`, and `CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]`

**Checkpoint**: `docker build ./backend` succeeds locally before proceeding to workflows.

---

## Phase 3: User Story 1 — CI Workflow (Priority: P1) 🎯 MVP

**Goal**: Every push and pull request to `main` automatically runs linting, formatting checks, and the test suite with a PostgreSQL service container, providing pass/fail status on each commit.

**User Story**: As a developer, I want every push to trigger automated quality checks so that regressions are caught before code reaches `main`.

**Independent Test**: Push a commit to any branch on GitHub; verify two check runs appear (`CI / lint` and `CI / test`), both passing. Introduce a lint error; verify the `lint` job fails.

- [x] T003 [US1] Create `.github/workflows/ci.yml` with `on: push` and `on: pull_request` (branches: [main]) triggers, two jobs (`lint` and `test`), and `defaults.run.working-directory: backend`
- [x] T004 [P] [US1] Add `lint` job to `.github/workflows/ci.yml`: `runs-on: ubuntu-latest`, steps: `actions/checkout@v6`, `astral-sh/setup-uv@v7` (version: "0.6.x", enable-cache: true, python-version: "3.13"), `uv sync --locked --dev`, `uv run ruff check .`, `uv run black --check .`, `uv run isort --check-only .`
- [x] T005 [P] [US1] Add `test` job to `.github/workflows/ci.yml`: `runs-on: ubuntu-latest`, PostgreSQL 17 service container (`POSTGRES_USER: echo`, `POSTGRES_PASSWORD: echo`, `POSTGRES_DB: echo_test`, port `5432:5432`, health-cmd `pg_isready` with 10s interval / 5s timeout / 5 retries), steps: `actions/checkout@v6`, `astral-sh/setup-uv@v7` (same config as lint), `uv sync --locked --dev`, then `uv run pytest --cov --cov-report=term-missing` with env `DATABASE_URL: postgresql+asyncpg://echo:echo@localhost:5432/echo_test` and `SECRET_KEY: ci-secret-key-not-used-in-tests`

---

## Phase 4: User Story 2 — CD Workflow / Docker Publish (Priority: P2)

**Goal**: Every merge to `main` automatically builds the Docker image and publishes it to `ghcr.io/<owner>/echo` with tags `:latest` and `:sha-<short-sha>`, using only `GITHUB_TOKEN` for authentication.

**User Story**: As a deployer, I want a versioned Docker image published to GHCR on every merge to `main` so that deployments are always traceable to a specific commit.

**Independent Test**: Merge a PR to `main`; verify the `CD / publish` job succeeds and `ghcr.io/<owner>/echo:latest` and `ghcr.io/<owner>/echo:sha-<sha>` are pullable from the GitHub Packages UI.

- [x] T006 [US2] Create `.github/workflows/cd.yml` with `on: push` (branches: [main]) trigger and top-level permissions `contents: read` and `packages: write`
- [x] T007 [US2] Add `publish` job to `.github/workflows/cd.yml`: `runs-on: ubuntu-latest`, steps: `actions/checkout@v6`, `docker/setup-buildx-action@v3`, `docker/login-action@v3` (registry: `ghcr.io`, username: `${{ github.actor }}`, password: `${{ secrets.GITHUB_TOKEN }}`), `docker/metadata-action@v5` (id: `meta`, images: `ghcr.io/${{ github.repository }}`, flavor: `latest=true`, tags: `type=sha,prefix=sha-,format=short`), `docker/build-push-action@v6` (context: `./backend`, file: `./backend/Dockerfile`, push: `true`, tags: `${{ steps.meta.outputs.tags }}`, labels: `${{ steps.meta.outputs.labels }}`, cache-from: `type=gha`, cache-to: `type=gha,mode=max`)

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Verify end-to-end behaviour and confirm constitutional compliance.

- [x] T008 [P] Verify `backend/Dockerfile` builds successfully by running `docker build -t echo-backend ./backend` locally and confirming the image starts with `docker run --rm -e DATABASE_URL=... -e SECRET_KEY=... -p 8000:8000 echo-backend`
- [x] T009 [P] Review `.github/workflows/ci.yml` and `.github/workflows/cd.yml` for hardcoded secrets; confirm only `${{ secrets.GITHUB_TOKEN }}` is used for authentication and all credentials are injected via environment variables
- [x] T010 Commit all three files (`backend/Dockerfile`, `.github/workflows/ci.yml`, `.github/workflows/cd.yml`) in a single atomic commit referencing task IDs, push to `002-github-actions-ci-cd` branch, and open a PR to `main` to trigger the CI workflow end-to-end

---

## Dependency Graph

```
T001 (dir structure)
  └─ T002 (Dockerfile)          ← foundational; blocks T007 (docker build in CD)
       └─ T007 (CD publish job)

T001
  └─ T003 (ci.yml skeleton)
       ├─ T004 (lint job)       ← parallel with T005
       └─ T005 (test job)       ← parallel with T004

T004 + T005 + T007 → T008, T009 (polish, parallel)
T008 + T009 → T010 (final commit + PR)
```

## Parallel Execution Opportunities

| Parallel Group | Tasks | Condition |
|----------------|-------|-----------|
| Group A | T004, T005 | After T003 (ci.yml skeleton exists) |
| Group B | T008, T009 | After T004, T005, T007 complete |

## Implementation Strategy

**MVP** (User Story 1 only — T001–T005): Gets automated quality gates running immediately. Every push is validated before CD is wired up.

**Full delivery** (all tasks): Adds Docker image publication to GHCR. Depends on the Dockerfile (T002) being correct before T007 is triggered on `main`.

**Suggested order for single-developer flow**:
T001 → T002 → T003 → T004 + T005 (parallel) → T006 → T007 → T008 + T009 (parallel) → T010
