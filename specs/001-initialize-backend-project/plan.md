# Implementation Plan: Initialize Backend Project

**Branch**: `001-initialize-backend-project` | **Date**: 2026-02-25 | **Spec**: user input "Initialize backend project"
**Input**: Constitution (`/.specify/memory/constitution.md`), Domain Model (`/docs/domain_model.puml`)

## Summary

Scaffold the FastAPI backend with the full foundational infrastructure: uv-managed Python 3.13 project,
async SQLAlchemy 2.0 + Alembic + PostgreSQL, OAuth 2.0 opaque-token auth, pytest test suite, and CI
quality gates — establishing the canonical `backend/` layout defined in the constitution.

## Technical Context

* **Language/Version**: Python 3.13+
* **Primary Dependencies**: FastAPI, SQLAlchemy 2.0 (async), Alembic, Pydantic v2, pydantic-settings, asyncpg, uvicorn,
  pytest, black, ruff, isort
* **Storage**: PostgreSQL 18 (asyncpg driver)
* **Testing**: pytest + pytest-asyncio + httpx (async test client) — 100% unit coverage enforced
* **Target Platform**: Linux server (Podman Compose for local dev; Makefile for task automation)
* **Project Type**: web-service (FastAPI REST API, foundation layer)
* **Performance Goals**: GET p95 ≤200ms, POST/PUT/PATCH p95 ≤500ms, cold-start ≤5s
* **Constraints**: All endpoints authenticated by default; public endpoints annotated `@public_endpoint`; no secrets in
  repo
* **Scale/Scope**: Foundation scaffold — no business-logic endpoints in this sprint; auth + health only

## Constitution Check

*Pre-design gate: PASSED. Post-design re-check: PASSED.*

| Gate                                                                         | Status | Notes                                                                                       |
|------------------------------------------------------------------------------|--------|---------------------------------------------------------------------------------------------|
| I. Code Quality — black + ruff + isort, type annotations                     | ✅ PASS | Configured in `pyproject.toml`; CI enforced                                                 |
| I. Code Quality — no circular cross-package deps                             | ✅ PASS | Single `backend/` package; `src/` layout                                                    |
| II. Test-First — 100% unit coverage, contract + integration tests            | ✅ PASS | pytest-cov at 100%; three-tier test structure                                               |
| III. API Contract — OpenAPI schema committed                                 | ✅ PASS | `shared/openapi.json` generated on CI and committed                                         |
| III. API Contract — OAuth 2.0 opaque tokens, server-side validation          | ✅ PASS | SHA-256 hashed tokens in `access_tokens` / `refresh_tokens` tables; lookup on every request |
| III. API Contract — token invalidation synchronous                           | ✅ PASS | `revoked_at = now()` UPDATE, not background job                                             |
| III. API Contract — `/v1/` prefix from first release                         | ✅ PASS | All routes under `/v1/`; `api_v1_prefix` in Settings                                        |
| III. API Contract — admin separate auth flow                                 | ✅ PASS | `admin_users` table independent of `users`; separate router (future sprint)                 |
| V. Performance — GET ≤200ms, POST ≤500ms; cold-start ≤5s                     | ✅ PASS | asyncpg + SQLAlchemy async; query logging in dev; token lookup = single index seek          |
| VI. Security — sensitive fields anonymised before logging                    | ✅ PASS | `SecretStr` for config secrets; logging middleware will anonymise user fields               |
| VI. Security — all endpoints authenticated by default; public ones annotated | ✅ PASS | `@public_endpoint` decorator on `/health`, `/auth/*`                                        |
| VI. Security — secrets not committed; `.env` in `.gitignore`                 | ✅ PASS | `.env.example` committed; `.env` ignored; CI secret scan                                    |
| VI. Security — Pydantic validation at API boundaries                         | ✅ PASS | All request bodies are Pydantic models; FastAPI enforces at the boundary                    |
| VI. Security — private attachments via expiring pre-signed URLs              | ✅ PASS | `storage_key` stored in DB; presigned URL generation in attachment service (future sprint)  |
| Tech Stack — uv; no pip/venv direct use                                      | ✅ PASS | `uv add`, `uv sync --frozen`; `requirements.txt` absent                                     |
| Tech Stack — `pyproject.toml` + `uv.lock` committed                          | ✅ PASS | `uv.lock` in git; `uv sync --frozen` fails CI if stale                                      |

**No violations. Complexity Tracking table omitted.**

## Project Structure

### Documentation (this feature)

```text
specs/001-initialize-backend-project/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   └── auth-api.md
└── tasks.md             # Phase 2 output (/speckit.tasks — NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Makefile                 # Repo-root task runner: make up / make down / make logs
compose.yml              # Podman Compose service definitions (postgres:18, rootless)
backend/
├── pyproject.toml       # uv-managed; black, ruff, isort, pytest config
├── uv.lock              # Committed lockfile
├── .env.example         # Template; .env in .gitignore
├── alembic.ini
├── migrations/
│   ├── env.py           # Async Alembic env
│   └── versions/
│       └── 0001_initial_schema.py
├── src/
│   ├── __init__.py
│   ├── main.py          # FastAPI app factory (lifespan)
│   ├── core/
│   │   ├── __init__.py
│   │   ├── config.py    # pydantic-settings Settings
│   │   ├── database.py  # Async engine + session factory
│   │   ├── security.py  # Token generation, hashing utilities
│   │   ├── deps.py      # FastAPI dependency injection (get_session, get_current_user)
│   │   └── decorators.py # @public_endpoint marker
│   ├── models/
│   │   ├── __init__.py
│   │   ├── base.py      # DeclarativeBase + common columns
│   │   ├── user.py      # User, Artist, AdminUser
│   │   ├── post.py      # Post
│   │   ├── attachment.py# Attachment hierarchy (joined-table inheritance)
│   │   ├── message.py   # MessageThread, Message
│   │   ├── friend.py    # Friend
│   │   └── auth.py      # AuthToken (access + refresh)
│   ├── services/
│   │   └── __init__.py  # Placeholder — populated by feature sprints
│   └── api/
│       ├── __init__.py
│       ├── router.py    # Root router (mounts v1)
│       └── v1/
│           ├── __init__.py
│           ├── health.py    # GET /v1/health (public)
│           └── auth.py      # POST /v1/auth/register, login, logout, refresh-token
└── tests/
    ├── conftest.py          # Async DB fixtures, test client
    ├── contract/
    │   └── test_auth_contract.py
    ├── integration/
    │   └── test_auth_integration.py
    └── unit/
        ├── test_security.py
        └── test_config.py
```

**Structure Decision**: Single `backend/` project per constitution monorepo layout. All source under
`src/` (src-layout) to avoid import ambiguity. `tests/` mirrors the three-tier contract / integration
/ unit split required by the constitution.

## Complexity Tracking

> No violations — table omitted.