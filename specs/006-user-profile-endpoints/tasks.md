# Tasks: User Profile Read and Self-Management Endpoints

**Input**: Design documents from `/specs/006-user-profile-endpoints/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `quickstart.md`, `contracts/profiles-api.md`

**Tests**: Tests are required for this feature (contract + integration + unit), must be written before implementation in short TDD red-green-refactor cycles, and must preserve 100% unit coverage for feature-touched backend use-case/service logic.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

**Path Note**: This repository uses the existing backend package namespace root `backend/src/backend/...`; Clean Architecture layer boundaries are enforced within that namespace as documented in `plan.md`.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`)
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish profile feature scaffolding and shared test entry points.

- [X] T001 Create profiles API adapter module scaffold in `backend/src/backend/presentation/api/v1/profiles.py`
- [X] T002 Create profile use-case module scaffolds in `backend/src/backend/application/profiles/use_cases.py` and `backend/src/backend/application/profiles/repositories.py`
- [X] T003 [P] Create profile domain module scaffolds in `backend/src/backend/domain/profiles/entities/profile.py` and `backend/src/backend/domain/profiles/exceptions.py`
- [X] T004 [P] Create SQLAlchemy profile repository scaffold in `backend/src/backend/infrastructure/persistence/repositories/profile_repository.py`
- [X] T005 [P] Create profile contract test scaffold in `backend/tests/contract/test_profiles_contract.py`
- [X] T006 [P] Create profile integration and unit test scaffolds in `backend/tests/integration/presentation/api/v1/test_profiles.py` and `backend/tests/unit/application/profiles/test_use_cases.py`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Complete shared profile building blocks that all user stories rely on.

**⚠️ CRITICAL**: No user story implementation starts until this phase is complete.

- [X] T007 Define profile repository port methods (`get_public_by_id`, `get_me_by_id`, `update_me`) in `backend/src/backend/application/profiles/repositories.py`
- [X] T008 [P] Define profile DTO/value objects (`PublicUserProfile`, `MeProfile`, `MeProfilePatch`) in `backend/src/backend/domain/profiles/entities/profile.py`
- [X] T009 [P] Define profile domain exceptions (`ProfileNotFoundError`, `UsernameConflictError`, `InvalidProfilePatchError`) in `backend/src/backend/domain/profiles/exceptions.py`
- [X] T010 Implement SQLAlchemy profile repository read methods for public/me projections in `backend/src/backend/infrastructure/persistence/repositories/profile_repository.py`
- [X] T011 Implement shared patch validation/normalization helpers (`username`, `bio`, `preferred_genres`) in `backend/src/backend/application/profiles/use_cases.py`
- [X] T012 [P] Register profiles router in API v1 module `backend/src/backend/presentation/api/v1/__init__.py`
- [X] T013 [P] Add shared profile response mapper functions in `backend/src/backend/presentation/api/v1/profiles.py`
- [X] T014 [P] Add foundational failing unit tests for patch payload validation rules in `backend/tests/unit/application/profiles/test_use_cases.py`

**Checkpoint**: Foundation ready; user stories can proceed.

---

## Phase 3: User Story 1 - View Another User Profile (Priority: P1) 🎯 MVP

**Goal**: Authenticated user retrieves a public profile snapshot for a target user by `{userId}`.

**Independent Test**: `GET /v1/users/{userId}` returns `200` with only public profile fields for existing users, `404` for unknown users, `422` for malformed UUID, and `401` when unauthenticated.

### Tests for User Story 1

- [X] T015 [P] [US1] Add `GET /v1/users/{userId}` contract tests for `200/404/422/401` in `backend/tests/contract/test_profiles_contract.py`
- [X] T016 [P] [US1] Add integration tests for public profile projection and sensitive-field exclusion in `backend/tests/integration/presentation/api/v1/test_profiles.py`
- [X] T017 [P] [US1] Add use-case unit tests for `get_user_profile` success/not-found branches in `backend/tests/unit/application/profiles/test_use_cases.py`

### Implementation for User Story 1

- [X] T018 [US1] Implement `get_user_profile` use-case orchestration in `backend/src/backend/application/profiles/use_cases.py`
- [X] T019 [US1] Implement `GET /v1/users/{userId}` endpoint and path validation wiring in `backend/src/backend/presentation/api/v1/profiles.py`
- [X] T020 [US1] Enforce public response projection (`id`, `username`, `bio`, `preferred_genres`, `is_artist`, `created_at`) in `backend/src/backend/presentation/api/v1/profiles.py`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - View Own Profile (Priority: P1)

**Goal**: Authenticated user retrieves own profile with caller-only fields from `/v1/me`.

**Independent Test**: `GET /v1/me` returns `200` with caller profile including `email` and `status`, `401` for missing auth, and `403` for disabled account.

### Tests for User Story 2

- [X] T021 [P] [US2] Add `GET /v1/me` contract tests for `200/401/403` and response shape in `backend/tests/contract/test_profiles_contract.py`
- [X] T022 [P] [US2] Add integration tests ensuring `/v1/me` returns authenticated user only with caller-only fields in `backend/tests/integration/presentation/api/v1/test_profiles.py`
- [X] T023 [P] [US2] Add use-case unit tests for `get_me_profile` retrieval path in `backend/tests/unit/application/profiles/test_use_cases.py`

### Implementation for User Story 2

- [X] T024 [US2] Implement `get_me_profile` use-case orchestration in `backend/src/backend/application/profiles/use_cases.py`
- [X] T025 [US2] Implement profile use-case factory/dependency wiring in `backend/src/backend/presentation/api/v1/profiles.py`
- [X] T026 [US2] Implement `GET /v1/me` endpoint response mapping in `backend/src/backend/presentation/api/v1/profiles.py`

**Checkpoint**: User Stories 1 and 2 are independently functional and testable.

---

## Phase 5: User Story 3 - Manage Own Profile (Priority: P2)

**Goal**: Authenticated user partially updates own mutable profile fields through `PATCH /v1/me`.

**Independent Test**: `PATCH /v1/me` updates only `username`, `bio`, and `preferred_genres`; returns `422` on empty/non-mutable payload attempts (`email`, `status`, `password_hash`, `is_artist`), `409` on username conflict, and `401` without auth.

### Tests for User Story 3

- [X] T027 [P] [US3] Add `PATCH /v1/me` contract tests for success, empty payload `422`, non-mutable field rejection (`email`, `status`, `password_hash`, `is_artist`) `422`, username conflict `409`, and unauthenticated `401` in `backend/tests/contract/test_profiles_contract.py`
- [X] T028 [P] [US3] Add integration tests for patch persistence, preferred-genres normalization, and immutability of non-mutable fields (`email`, `status`, `password_hash`, `is_artist`) in `backend/tests/integration/presentation/api/v1/test_profiles.py`
- [X] T029 [P] [US3] Add use-case unit tests for update validation, normalization, and conflict mapping in `backend/tests/unit/application/profiles/test_use_cases.py`

### Implementation for User Story 3

- [X] T030 [US3] Implement `update_me_profile` use-case logic with partial-merge semantics in `backend/src/backend/application/profiles/use_cases.py`
- [X] T031 [US3] Implement repository update method for mutable fields (`username`, `bio`, `preferred_genres`) in `backend/src/backend/infrastructure/persistence/repositories/profile_repository.py`
- [X] T032 [US3] Implement `PATCH /v1/me` request model and endpoint validation in `backend/src/backend/presentation/api/v1/profiles.py`
- [X] T033 [US3] Map username uniqueness violations to `409 Conflict` in `backend/src/backend/application/profiles/use_cases.py`
- [X] T034 [US3] Return updated caller profile projection after patch in `backend/src/backend/presentation/api/v1/profiles.py`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize contracts, verification artifacts, and quality gates across stories.

- [X] T035 [P] Update profile endpoint contract in `specs/006-user-profile-endpoints/contracts/profiles-api.md`
- [X] T036 Regenerate and verify OpenAPI schema includes `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me` in `shared/openapi.json`
- [X] T037 [P] Run quality-gate commands `make lint check` and `make test test-args="-k profiles"` from repository root; record outcomes in `specs/006-user-profile-endpoints/validation.md`
- [X] T038 [P] Verify 100% unit coverage for feature-touched profile use-case/service logic in `backend/tests/unit/application/profiles/test_use_cases.py`
- [X] T039 Measure and record profile endpoint latency against targets in `specs/006-user-profile-endpoints/validation.md`
- [X] T040 Capture TDD evidence (failing tests first, minimal implementation, passing tests) in `specs/006-user-profile-endpoints/validation.md`
- [X] T041 Run backend architecture boundary/import checks and record pass/fail evidence in `specs/006-user-profile-endpoints/validation.md`
- [X] T042 Implement SQLAlchemy statement-count instrumentation fixture in `backend/tests/integration/presentation/api/v1/test_profiles.py`, assert bounded query counts for `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me`, review SQL query logs for the same endpoints, and document per-endpoint evidence in `specs/006-user-profile-endpoints/validation.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies; start immediately.
- **Foundational (Phase 2)**: Depends on Setup; blocks all user stories until complete.
- **User Stories (Phases 3-5)**: Depend on Foundational completion.
- **Polish (Phase 6)**: Depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: Starts after Phase 2; no dependency on US2/US3.
- **US2 (P1)**: Starts after Phase 2; no dependency on US1/US3.
- **US3 (P2)**: Starts after Phase 2 and reuses shared profile infrastructure; can proceed after US1/US2 checks are green.

### Within Each User Story

- Write tests first and confirm they fail.
- Implement use-case logic before endpoint wiring.
- Integrate repository behavior before finishing adapter mapping.
- Complete and verify each story independently before moving on.

### Parallel Opportunities

- Phase 1 tasks marked `[P]` can run in parallel.
- Phase 2 tasks marked `[P]` can run in parallel after T007.
- In each user story, contract/integration/unit tests marked `[P]` can run in parallel.
- Story phases can be split across teammates once Phase 2 is complete.

---

## Parallel Example: User Story 1

```bash
Task: "Add GET /v1/users/{userId} contract tests in backend/tests/contract/test_profiles_contract.py"
Task: "Add public profile integration tests in backend/tests/integration/presentation/api/v1/test_profiles.py"
Task: "Add get_user_profile unit tests in backend/tests/unit/application/profiles/test_use_cases.py"
```

## Parallel Example: User Story 2

```bash
Task: "Add GET /v1/me contract tests in backend/tests/contract/test_profiles_contract.py"
Task: "Add /v1/me integration tests in backend/tests/integration/presentation/api/v1/test_profiles.py"
Task: "Add get_me_profile unit tests in backend/tests/unit/application/profiles/test_use_cases.py"
```

## Parallel Example: User Story 3

```bash
Task: "Add PATCH /v1/me contract tests in backend/tests/contract/test_profiles_contract.py"
Task: "Add PATCH /v1/me integration tests in backend/tests/integration/presentation/api/v1/test_profiles.py"
Task: "Add update_me_profile unit tests in backend/tests/unit/application/profiles/test_use_cases.py"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate `GET /v1/users/{userId}` independently.
4. Demo/deploy MVP profile-read capability.

### Incremental Delivery

1. Foundation complete (Phases 1-2).
2. Deliver US1 (`GET /v1/users/{userId}`) as MVP.
3. Deliver US2 (`GET /v1/me`) as next independent increment.
4. Deliver US3 (`PATCH /v1/me`) as profile-management increment.
5. Complete Phase 6 polish and quality gates.

### Parallel Team Strategy

1. Team aligns on Phase 1-2 together.
2. After Phase 2:
   - Developer A: US1
   - Developer B: US2
   - Developer C: US3 tests + repository update prep
3. Merge stories independently after each story checkpoint passes.
