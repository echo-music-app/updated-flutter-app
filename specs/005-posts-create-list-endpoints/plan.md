# Implementation Plan: Create and List Posts Endpoints

**Branch**: `005-posts-create-list-endpoints` | **Date**: 2026-03-15 | **Spec**: `spec.md`
**Input**: Feature specification from `/specs/005-posts-create-list-endpoints/spec.md`

## Summary

Add authenticated backend endpoints for post creation and listing via route-based resources: `GET /v1/posts` (following feed), `GET /v1/me/posts` (own posts), and `GET /v1/user/{userId}/posts` (specific user posts). The implementation includes attachment payloads in list responses, adopts single-table inheritance for attachment persistence, adds polymorphic secure attachment URL signing (Nginx secure link default + CloudFront option), and is organized in constitution-aligned Clean Architecture layers.

## Technical Context

**Language/Version**: Python 3.13+  
**Primary Dependencies**: FastAPI, SQLAlchemy (async), Pydantic v2, pytest  
**Storage**: PostgreSQL 18  
**Testing**: pytest (contract + integration + unit), strict TDD (short red-green-refactor cycles), and 100% unit coverage for feature-touched use-case/service logic  
**Target Platform**: Linux backend service  
**Project Type**: web-service (backend API)  
**Performance Goals**: GET p95 <= 200ms, POST p95 <= 500ms  
**Constraints**: Auth required by default; route-based list semantics (no `scope` parameter); stable cursor pagination; attachment STI mapping to avoid subtype joins; secure attachment URLs via pluggable providers (default `nginx_secure_link`, optional CloudFront override), fixed `5m` TTL, fail-closed on signing errors; implementation follows short-cycle TDD and preserves 100% unit coverage for feature-touched use-case/service logic; Clean Architecture dependency rule (inward-only imports)  
**Scale/Scope**: Backend API slice under `/v1/posts`, `/v1/me/posts`, and `/v1/user/{userId}/posts`; no frontend/mobile implementation changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|---|---|---|
| I. Code Quality & Standards | ✅ PASS | Existing Python tooling (`black`, `isort`, `ruff`) and typed signatures remain required |
| II. Test-First Discipline | ✅ PASS | Plan requires strict short-cycle TDD and 100% unit coverage for feature-touched use-case/service logic |
| III. API Contract Integrity | ✅ PASS | Endpoints are versioned under `/v1`; contract artifacts documented |
| V. Performance Standards | ✅ PASS | Cursor pagination + STI attachment mapping reduce feed query instability/join overhead |
| VI. Security by Design | ✅ PASS | Authenticated access, signed attachment URLs (Nginx/CloudFront), fixed short TTL, and fail-closed behavior are enforced |
| VIII. Clean Architecture | ✅ PASS | Feature structure and tasks align to `domain/application/adapters/infrastructure` with inward-only dependencies |

*Post-design re-check*: All gates remain satisfied after Phase 1 artifacts (`research.md`, `data-model.md`, `contracts/posts-api.md`, `quickstart.md`) and latest clarifications.

## Project Structure

### Documentation (this feature)

```text
specs/005-posts-create-list-endpoints/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── validation.md
├── contracts/
│   └── posts-api.md
└── tasks.md                 # generated later by /speckit.tasks
```

### Source Code (repository root)

```text
backend/src/
├── domain/
│   └── posts/
│       ├── entities/
│       │   ├── post.py                       # NEW: post entity/value objects in domain layer
│       │   └── attachment.py                 # UPDATED: STI-aware attachment entity definitions
│       └── value_objects/
│           └── post_cursor.py                # NEW: cursor position value object
├── application/
│   ├── use_cases/
│   │   ├── create_post.py                    # NEW: create-post orchestration
│   │   └── list_posts.py                     # NEW: list-posts orchestration
│   └── ports/
│       ├── post_repository.py                # NEW: abstract post repository contract
│       ├── friend_repository.py              # NEW: abstract friend-relation lookup contract
│       └── attachment_url_signer.py          # NEW: secure attachment URL signer port
├── adapters/
│   ├── api/v1/
│   │   └── posts.py                          # NEW: route handlers + DTO mapping
│   ├── security/
│   │   ├── nginx_secure_link_signer.py       # NEW: default secure-link signer adapter
│   │   └── cloudfront_signed_url_signer.py   # NEW: CloudFront signed URL adapter
│   └── repositories/
│       ├── sqlalchemy_post_repository.py     # NEW: post persistence adapter
│       └── sqlalchemy_friend_repository.py   # NEW: friend-relation adapter
└── infrastructure/
    ├── persistence/models/
    │   └── attachment.py                     # UPDATED: STI DB mapping
    └── migrations/versions/
        └── xxxx_attachment_sti.py            # NEW: attachment STI migration

backend/tests/
├── contract/
│   └── test_posts_contract.py
├── integration/
│   └── test_posts_integration.py
└── unit/
    └── test_posts_use_cases.py
```

**Structure Decision**: Enforce constitution-mandated Clean Architecture layering for this feature and map API/service/persistence responsibilities into `adapters`, `application`, and `infrastructure` with domain isolation.

## Phase 0: Research

See `research.md` for selected decisions on route-based list semantics, follow-graph derivation, response attachment inclusion, STI persistence mapping, cursor pagination, and secure URL provider strategy.

## Phase 1: Design & Contracts

- Data entities and response models documented in `data-model.md`.
- API interfaces documented in `contracts/posts-api.md`.
- Implementation + verification sequence documented in `quickstart.md`.

## Complexity Tracking

> No constitution violations requiring exception tracking.
