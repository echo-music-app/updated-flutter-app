# Implementation Plan: User Profile Read and Self-Management Endpoints

**Branch**: `006-user-profile-endpoints` | **Date**: 2026-03-15 | **Spec**: `spec.md`
**Input**: Feature specification from `/specs/006-user-profile-endpoints/spec.md`

## Summary

Add authenticated backend profile endpoints aligned to feature `005` principles: `GET /v1/users/{userId}` for public profile viewing and `GET /v1/me` + `PATCH /v1/me` for caller profile retrieval and management. The implementation keeps route-driven semantics (no profile mode query switches), enforces strict validation and conflict handling, updates API contract artifacts, and follows constitution-aligned Clean Architecture and test-first delivery requirements.

## Technical Context

**Language/Version**: Python 3.13+
**Primary Dependencies**: FastAPI, SQLAlchemy (async), Pydantic v2, pytest
**Storage**: PostgreSQL 18 (`users` table; no new profile table)
**Testing**: pytest (contract + integration + unit), strict TDD (short red-green-refactor cycles), and 100% unit coverage for feature-touched use-case/service logic
**Target Platform**: Linux backend service
**Project Type**: web-service (backend API)
**Performance Goals**: GET p95 <= 200ms, PATCH p95 <= 500ms
**Constraints**: Auth required on all endpoints; path-driven endpoint semantics (`/users/{userId}` vs `/me`); partial update semantics for `/v1/me`; strict input validation; no sensitive field leakage from public profile endpoint; OpenAPI/contract synchronization with committed artifact at `shared/openapi.json`; Clean Architecture inward-only imports
**Scale/Scope**: Backend API slice for profile read/manage endpoints and related tests/contracts; no frontend/mobile implementation changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|---|---|---|
| I. Code Quality & Standards | ✅ PASS | Python typing/linting/formatting standards remain mandatory for all touched backend modules |
| II. Test-First Discipline | ✅ PASS | Plan requires contract + integration + unit tests first, with short TDD cycles and 100% unit coverage on touched use cases/services |
| III. API Contract Integrity | ✅ PASS | Endpoints remain under `/v1`; contract docs and OpenAPI updates are required |
| V. Performance Standards | ✅ PASS | Read/update profile endpoints have explicit p95 goals and simple indexed lookup/update paths |
| VI. Security by Design | ✅ PASS | Authenticated-only access, explicit public vs private field projections, and strict input validation are enforced |
| VIII. Clean Architecture | ✅ PASS | Profile behavior split across domain/application/presentation-adapter/infrastructure boundaries with inward dependency flow; repository namespace adaptation is documented in Complexity Tracking |

*Post-design re-check*: All gates remain satisfied after Phase 1 artifacts (`research.md`, `data-model.md`, `contracts/profiles-api.md`, `quickstart.md`) and clarifications.

## Project Structure

### Documentation (this feature)

```text
specs/006-user-profile-endpoints/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── profiles-api.md
└── tasks.md                 # generated later by /speckit.tasks
```

### Source Code (repository root)

```text
backend/src/backend/
├── domain/
│   └── profiles/
│       ├── entities/
│       │   └── profile.py                         # NEW: profile projection value objects/entities
│       └── exceptions.py                          # NEW: profile-domain error definitions
├── application/
│   └── profiles/
│       ├── use_cases.py                           # NEW: GetUserProfile/GetMeProfile/UpdateMeProfile orchestration
│       └── repositories.py                        # NEW: profile repository protocol(s)
├── presentation/
│   └── api/v1/
│       ├── profiles.py                            # NEW: endpoint handlers + request/response models
│       └── __init__.py                            # UPDATED: include profiles router in v1
└── infrastructure/
    └── persistence/
        └── repositories/
            └── profile_repository.py              # NEW: SQLAlchemy profile repository implementation

backend/tests/
├── contract/
│   └── test_profiles_contract.py                  # NEW
├── integration/
│   └── presentation/api/v1/
│       └── test_profiles.py                       # NEW
└── unit/
    └── application/profiles/
        └── test_use_cases.py                      # NEW
```

**Structure Decision**: Use the existing backend package namespace root (`backend/src/backend/...`) for feature integration while preserving constitution Clean Architecture boundaries at module level (`domain`/`application`/`presentation-adapter`/`infrastructure`) and validating boundaries explicitly during quality gates.

## Phase 0: Research

See `research.md` for selected decisions on endpoint semantics, public/private profile field projection, patch validation, conflict handling, and repository/use-case layering.

## Phase 1: Design & Contracts

- Data entities and request/response models documented in `data-model.md`.
- API interfaces documented in `contracts/profiles-api.md`.
- Implementation + verification sequence documented in `quickstart.md`.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Backend package namespace uses `backend/src/backend/...` instead of constitution example `backend/src/...` | Existing application modules, imports, and runtime wiring are anchored to `backend/src/backend/...`; feature work must remain compatible with current codebase. | Moving only this feature to `backend/src/...` creates split architecture roots and broken imports; full repo-wide relocation is out-of-scope for this feature and increases regression risk. |
