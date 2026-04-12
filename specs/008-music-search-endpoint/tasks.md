# Tasks: Unified Music Search Endpoint

**Input**: Design documents from `/specs/008-music-search-endpoint/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/music-search-api.md`, `quickstart.md`

**Tests**: Tests are required for this feature (contract + integration + unit). Per constitution and plan, write tests first, confirm they fail, then implement in short red-green-refactor cycles.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`)
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature scaffolding and test entry points.

- [X] T001 Create feature package scaffolds in `backend/src/domain/music_search/__init__.py`, `backend/src/application/music_search/__init__.py`, and `backend/src/infrastructure/music_providers/__init__.py`
- [X] T002 Create API module scaffold for search endpoint in `backend/src/adapters/api/v1/music_search.py`
- [X] T003 [P] Create contract test scaffold in `backend/tests/contract/test_music_search_contract.py`
- [X] T004 [P] Create integration test scaffold in `backend/tests/integration/presentation/api/v1/test_music_search.py`
- [X] T005 [P] Create unit test scaffolds in `backend/tests/unit/application/music_search/test_use_cases.py` and `backend/tests/unit/infrastructure/music_providers/test_provider_clients.py`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared foundations required by all user stories.

**⚠️ CRITICAL**: No user story implementation starts until this phase is complete.

- [X] T006 Add music-provider configuration settings (credentials, token URLs, default market, request timeouts, bulkhead limits) in `backend/src/infrastructure/config.py`
- [X] T007 [P] Implement core music-search entities and summary models in `backend/src/domain/music_search/entities.py`
- [X] T008 [P] Implement music-search/provider exception hierarchy in `backend/src/domain/music_search/exceptions.py`
- [X] T009 [P] Define provider client and orchestration port protocols in `backend/src/application/music_search/ports.py`
- [X] T010 Implement shared request normalization (preserving valid punctuation/non-Latin terms) and per-type limit validation helpers in `backend/src/application/music_search/use_cases.py`
- [X] T011 [P] Implement Spotify token acquisition/caching foundation in `backend/src/infrastructure/music_providers/spotify_search_client.py`
- [X] T012 [P] Implement SoundCloud token acquisition/caching foundation in `backend/src/infrastructure/music_providers/soundcloud_search_client.py`
- [X] T013 Register music search router in `backend/src/adapters/api/v1/__init__.py`
- [X] T014 Implement dependency wiring/factories for `MusicSearchUseCase` in `backend/src/adapters/api/v1/music_search.py`

**Checkpoint**: Shared foundations complete; user stories can begin.

---

## Phase 3: User Story 1 - Search Once Across Music Sources (Priority: P1) 🎯 MVP

**Goal**: Authenticated caller can submit a single search term and receive consolidated grouped arrays from Spotify and SoundCloud.

**Independent Test**: `POST /v1/search/music` with valid auth/body returns grouped `tracks[]`, `albums[]`, `artists[]` including results from both providers when available; no-match returns all arrays empty.

### Tests for User Story 1

- [X] T015 [P] [US1] Add contract tests for authenticated `POST /v1/search/music` success, no-match grouped arrays, request validation, accepted punctuation/non-Latin terms, and localized validation messages with `Accept-Language` fallback to `en` in `backend/tests/contract/test_music_search_contract.py`
- [X] T016 [P] [US1] Add integration tests for merged Spotify+SoundCloud grouped responses and non-Latin/punctuation query handling in `backend/tests/integration/presentation/api/v1/test_music_search.py`
- [X] T017 [P] [US1] Add use-case unit tests for provider fanout and per-type limit handling in `backend/tests/unit/application/music_search/test_use_cases.py`

### Implementation for User Story 1

- [X] T018 [US1] Implement Spotify multi-type search (`track,album,artist`) and normalization in `backend/src/infrastructure/music_providers/spotify_search_client.py`
- [X] T019 [US1] Implement SoundCloud `/tracks`, `/playlists`, `/users` search normalization in `backend/src/infrastructure/music_providers/soundcloud_search_client.py`
- [X] T020 [US1] Implement baseline unified aggregation flow with always-present grouped arrays in `backend/src/application/music_search/use_cases.py`
- [X] T021 [US1] Implement authenticated `POST /v1/search/music` endpoint contract including `Accept-Language` negotiation and locale fallback context propagation in `backend/src/adapters/api/v1/music_search.py`
- [X] T022 [US1] Map use-case results to API response DTOs (`tracks`, `albums`, `artists`, `summary`) in `backend/src/adapters/api/v1/music_search.py`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - Understand Result Origin and Relevance (Priority: P2)

**Goal**: Results expose clear source attribution, standardized metadata shape, dedupe behavior, and deterministic ordering.

**Independent Test**: Repeated searches under identical provider availability produce deterministic ordering; each item includes standardized core fields and source attribution.

### Tests for User Story 2

- [X] T023 [P] [US2] Add contract tests for standardized item fields and `sources[]` attribution in `backend/tests/contract/test_music_search_contract.py`
- [X] T024 [P] [US2] Add integration tests for deterministic ordering across repeated calls in `backend/tests/integration/presentation/api/v1/test_music_search.py`
- [X] T025 [P] [US2] Add unit tests for dedupe keys and attribution merge logic in `backend/tests/unit/application/music_search/test_use_cases.py`

### Implementation for User Story 2

- [X] T026 [US2] Implement Spotify standardized field mapping (`display_name`, creator, duration, links, artwork) in `backend/src/infrastructure/music_providers/spotify_search_client.py`
- [X] T027 [US2] Implement SoundCloud standardized field mapping for track/album-candidate/artist items in `backend/src/infrastructure/music_providers/soundcloud_search_client.py`
- [X] T028 [US2] Implement cross-source deduplication within each type while preserving `sources[]` in `backend/src/application/music_search/use_cases.py`
- [X] T029 [US2] Implement deterministic relevance sorting with stable tie-breakers in `backend/src/application/music_search/use_cases.py`
- [X] T030 [US2] Implement summary count calculation (`total_count`, `per_type_counts`, `per_source_counts`) in `backend/src/application/music_search/use_cases.py`
- [X] T031 [US2] Enforce response DTO shape/typing for normalized items in `backend/src/adapters/api/v1/music_search.py`

**Checkpoint**: User Stories 1 and 2 are independently functional and testable.

---

## Phase 5: User Story 3 - Get Partial Results During Source Outages (Priority: P2)

**Goal**: Service remains available during single-provider failures and returns explicit degraded or unavailable outcomes.

**Independent Test**: If one provider fails/throttles/times out, endpoint returns partial data with `unavailable` source status; if both fail, endpoint returns service-unavailable outcome.

### Tests for User Story 3

- [X] T032 [P] [US3] Add contract tests for partial (`is_partial=true`) and both-unavailable outcomes, including localized warnings/outcomes via `Accept-Language` and unsupported-locale fallback to `en` in `backend/tests/contract/test_music_search_contract.py`
- [X] T033 [P] [US3] Add integration tests for one-provider timeout/throttle while other provider succeeds in `backend/tests/integration/presentation/api/v1/test_music_search.py`
- [X] T034 [P] [US3] Add unit tests for bulkhead fail-fast behavior and status transitions (`matched`/`no_matches`/`unavailable`) in `backend/tests/unit/application/music_search/test_use_cases.py`

### Implementation for User Story 3

- [X] T035 [US3] Implement Spotify provider error translation (401/403/429/5xx/timeout) to domain-level availability states in `backend/src/infrastructure/music_providers/spotify_search_client.py`
- [X] T036 [US3] Implement SoundCloud provider error translation (401/429/5xx/timeout) to domain-level availability states in `backend/src/infrastructure/music_providers/soundcloud_search_client.py`
- [X] T037 [US3] Implement per-provider bulkhead + timeout guards in `backend/src/application/music_search/use_cases.py`
- [X] T038 [US3] Implement partial-response synthesis (`source_statuses`, `is_partial`, localized `warnings`) in `backend/src/application/music_search/use_cases.py`
- [X] T039 [US3] Implement both-providers-unavailable to HTTP 503 mapping with localized service-unavailable outcome text in `backend/src/adapters/api/v1/music_search.py`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize quality gates, observability, docs/contracts, and validation artifacts.

- [X] T040 [P] Add provider-client token cache/refresh unit coverage in `backend/tests/unit/infrastructure/music_providers/test_provider_clients.py`
- [X] T041 [P] Add contract regression test for unauthenticated `POST /v1/search/music` returning `401` in `backend/tests/contract/test_music_search_contract.py`
- [X] T042 Regenerate and verify OpenAPI schema for `POST /v1/search/music` in `shared/openapi.json`
- [X] T043 [P] Add structured provider latency/status logging hooks in `backend/src/application/music_search/use_cases.py`
- [X] T044 Run backend quality-gate commands from `specs/008-music-search-endpoint/quickstart.md` and record results in `specs/008-music-search-endpoint/validation.md`
- [X] T045 [P] Document final scenario validation notes for full/partial/unavailable flows in `specs/008-music-search-endpoint/quickstart.md`
- [X] T046 Add performance benchmark test and report for `SC-001` (p95 `<=500ms`) in `backend/tests/integration/presentation/api/v1/test_music_search_performance.py` and `specs/008-music-search-endpoint/validation.md`
- [X] T047 Add benchmark query-set evaluation for `SC-002` (>=90% dual-source inclusion) in `backend/tests/integration/presentation/api/v1/test_music_search_benchmark_sources.py` and `specs/008-music-search-endpoint/validation.md`
- [X] T048 Add relevance quality evaluation for `SC-006` (>=85% intended-type hit in top-10 over 50 queries) in `backend/tests/integration/presentation/api/v1/test_music_search_relevance.py` and `specs/008-music-search-endpoint/validation.md`
- [X] T049 Verify and record 100% unit coverage for feature-touched backend logic in `backend/tests/unit/application/music_search/test_use_cases.py`, `backend/tests/unit/infrastructure/music_providers/test_provider_clients.py`, and `specs/008-music-search-endpoint/validation.md`
- [X] T050 Add read-only safety integration test asserting no persistence/provider mutation side effects for `POST /v1/search/music` in `backend/tests/integration/presentation/api/v1/test_music_search_read_only.py` and `specs/008-music-search-endpoint/validation.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Depends on Phase 3 baseline endpoint behavior.
- **Phase 5 (US3)**: Depends on Phase 3 baseline endpoint behavior.
- **Phase 6 (Polish)**: Depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: Starts immediately after Foundational; no dependency on other stories.
- **US2 (P2)**: Builds on US1 response pipeline (normalization/dedupe/ranking), but remains independently testable.
- **US3 (P2)**: Builds on US1 pipeline for resilience/error paths, but remains independently testable.

### Within Each User Story

- Write tests first and confirm failures.
- Implement provider/client logic before use-case orchestration wiring.
- Implement use-case logic before endpoint response mapping.
- Re-run story-specific contract/integration/unit tests before moving on.

### Parallel Opportunities

- Setup `[P]` tasks can run in parallel.
- Foundational `[P]` tasks can run in parallel (config-independent files).
- Per story, contract/integration/unit test tasks can run in parallel.
- In US2 and US3, provider-specific adapter tasks can run in parallel because they touch different files.

---

## Parallel Example: User Story 1

```bash
Task: "T015 [US1] Contract tests in backend/tests/contract/test_music_search_contract.py"
Task: "T016 [US1] Integration tests in backend/tests/integration/presentation/api/v1/test_music_search.py"
Task: "T017 [US1] Unit tests in backend/tests/unit/application/music_search/test_use_cases.py"
```

## Parallel Example: User Story 2

```bash
Task: "T026 [US2] Spotify mapping in backend/src/infrastructure/music_providers/spotify_search_client.py"
Task: "T027 [US2] SoundCloud mapping in backend/src/infrastructure/music_providers/soundcloud_search_client.py"
```

## Parallel Example: User Story 3

```bash
Task: "T035 [US3] Spotify error translation in backend/src/infrastructure/music_providers/spotify_search_client.py"
Task: "T036 [US3] SoundCloud error translation in backend/src/infrastructure/music_providers/soundcloud_search_client.py"
Task: "T034 [US3] Bulkhead/status unit tests in backend/tests/unit/application/music_search/test_use_cases.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. Validate US1 independently with contract/integration/unit tests.
5. Demo authenticated unified search baseline.

### Incremental Delivery

1. Foundation complete (Phases 1-2).
2. Deliver US1 (core unified search).
3. Deliver US2 (result quality and deterministic relevance).
4. Deliver US3 (resilience/degraded behavior).
5. Finish polish and full quality gates.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. After US1 baseline lands:
   - Developer A: US2 normalization/dedupe/ranking
   - Developer B: US3 bulkhead/error handling
3. Merge when each story passes its independent test criteria.
