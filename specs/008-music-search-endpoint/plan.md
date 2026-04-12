# Implementation Plan: Unified Music Search Endpoint

**Branch**: `008-music-search-endpoint` | **Date**: 2026-03-19 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/008-music-search-endpoint/spec.md`

## Summary

Implement an authenticated backend endpoint `POST /v1/search/music` that accepts a single free-text term and returns one consolidated payload grouped into `tracks[]`, `albums[]`, and `artists[]`. The service fans out searches to Spotify and SoundCloud in parallel via dedicated infrastructure clients, normalizes provider payloads into a shared schema, deduplicates near-identical items within each type, and returns deterministic relevance ordering plus per-source status (`matched`, `no_matches`, `unavailable`). Provider failures are isolated with per-provider bulkheads/timeouts so the endpoint can return controlled partial responses instead of failing the whole request.

## Technical Context

**Language/Version**: Python 3.13+  
**Primary Dependencies**: FastAPI, Pydantic v2, `httpx` (async clients), SQLAlchemy (existing auth/session integration), pytest  
**Storage**: N/A for search results (read-through aggregation only); existing PostgreSQL auth/session tables remain unchanged  
**Testing**: `pytest` contract + integration + unit tests; strict TDD with failing tests first and 100% unit coverage for feature-touched search orchestration logic  
**Target Platform**: Linux backend service  
**Project Type**: Backend web-service feature slice  
**Performance Goals**: Meet constitution-aligned write-endpoint target for `POST /v1/search/music` (p95 `<=500ms` under expected load) while preserving predictable degraded behavior under provider issues  
**Constraints**: Authenticated read-only operation; endpoint contract fixed to `POST /v1/search/music`; single free-text term; default limit `20` and max `50` per type; grouped arrays always present; deterministic ordering; cross-source dedupe within type; provider bulkheads and timeouts; no secrets in code; provider credentials loaded from env vars  
**Scale/Scope**: One unified endpoint `POST /v1/search/music` plus supporting Spotify/SoundCloud client adapters and orchestration logic; no mobile/admin surface changes

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|---|---|---|
| I. Code Quality & Standards | ✅ PASS | Python feature files follow existing formatting/lint/type expectations (`black`, `isort`, `ruff`) |
| II. Test-First Discipline | ✅ PASS | Plan requires contract/integration/unit test-first workflow before implementation |
| III. API Contract Integrity | ✅ PASS | New endpoint is versioned under `/v1`; explicit API contract artifact included in `contracts/` |
| V. Performance Standards | ✅ PASS | Parallel provider fanout, strict timeout budget, and fail-fast provider bulkheads support bounded latency |
| VI. Security by Design | ✅ PASS | Provider secrets remain env-only; request validation enforced at API boundary; failures return sanitized status details |
| VIII. Clean Architecture | ✅ PASS | Separation maintained across domain/application/presentation/infrastructure layers with inward dependency flow |

*Post-design re-check*: All gates remain satisfied after producing `research.md`, `data-model.md`, `contracts/music-search-api.md`, and `quickstart.md`.

## Project Structure

### Documentation (this feature)

```text
specs/008-music-search-endpoint/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── music-search-api.md
└── tasks.md                 # generated later by /speckit.tasks
```

### Source Code (repository root)

```text
backend/src/
├── domain/
│   └── music_search/
│       ├── entities.py                      # NEW: normalized search entities and summaries
│       └── exceptions.py                    # NEW: provider and aggregation error types
├── application/
│   └── music_search/
│       ├── ports.py                         # NEW: provider client protocols + bulkhead abstractions
│       └── use_cases.py                     # NEW: unified search orchestration, dedupe, ordering
├── adapters/
│   └── api/v1/
│       ├── music_search.py                  # NEW: POST /v1/search/music endpoint + DTO mapping
│       └── __init__.py                      # UPDATED: register music search router
└── infrastructure/
    ├── config.py                            # UPDATED: provider credentials, timeout and bulkhead settings
    └── music_providers/
        ├── spotify_search_client.py         # NEW: Spotify Search API adapter
        └── soundcloud_search_client.py      # NEW: SoundCloud search adapters (/tracks, /playlists, /users)

backend/tests/
├── contract/
│   └── test_music_search_contract.py        # NEW: API contract tests for full/partial/unavailable responses
├── integration/
│   └── presentation/api/v1/
│       └── test_music_search.py             # NEW: endpoint integration tests with mocked provider responses
└── unit/
    ├── application/music_search/
    │   └── test_use_cases.py                # NEW: dedupe, ordering, status, fallback logic
    └── infrastructure/music_providers/
        └── test_provider_clients.py         # NEW: provider request/response mapping and error handling
```

**Structure Decision**: Backend-only extension in existing FastAPI service aligned to constitution-mandated backend layout (`domain`, `application`, `adapters`, `infrastructure`). New feature modules are isolated under `music_search` namespaces and HTTP endpoint wiring is implemented in adapter layer under `/v1`.

## Phase 0: Research

See `research.md` for selected decisions on Spotify/SoundCloud API contracts, provider authentication strategy, pagination/limit behavior, album mapping strategy for SoundCloud, and bulkhead-based resilience.

## Phase 1: Design & Contracts

- Data entities and validation/state rules are documented in `data-model.md`.
- API and provider interface contracts are documented in `contracts/music-search-api.md`.
- Implementation and verification sequence is documented in `quickstart.md`.

## Complexity Tracking

> No constitution violations requiring exception tracking.
