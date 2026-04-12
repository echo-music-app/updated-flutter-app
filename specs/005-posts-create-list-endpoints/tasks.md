# Tasks: Create and List Posts Endpoints

**Input**: Design documents from `/specs/005-posts-create-list-endpoints/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/posts-api.md`, `quickstart.md`

**Tests**: Tests are required for this feature (contract + integration + unit), must be written before implementation in short TDD red-green-refactor cycles, and must preserve 100% unit coverage for feature-touched backend use-case/service logic.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: User story label (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Every task includes an exact file path

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish feature scaffolding and shared test entry points.

- [X] T001 Create posts API adapter module scaffold in `backend/src/adapters/api/v1/posts.py`
- [X] T002 Create post use-case module scaffolds in `backend/src/application/use_cases/create_post.py` and `backend/src/application/use_cases/list_posts.py`
- [X] T003 [P] Create posts contract test module scaffold in `backend/tests/contract/test_posts_contract.py`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Complete shared building blocks that all user stories rely on.

**⚠️ CRITICAL**: No user story implementation starts until this phase is complete.

- [X] T004 Add foundational failing unit tests for cursor and attachment mapping helpers in `backend/tests/unit/test_posts_use_cases.py`
- [X] T005 [P] Add failing integration tests for attachment STI query behavior (no subtype-table joins) in `backend/tests/integration/test_posts_integration.py`
- [X] T006 [P] Add failing unit tests for signer port contract and provider selection policy in `backend/tests/unit/test_posts_use_cases.py`
- [X] T007 Implement attachment STI persistence mapping in `backend/src/infrastructure/persistence/models/attachment.py`
- [X] T008 Add attachment STI migration script in `backend/src/infrastructure/migrations/versions/xxxx_attachment_sti.py`
- [X] T009 [P] Register posts router adapter in `backend/src/adapters/api/router.py`
- [X] T010 [P] Implement shared cursor value object and codec in `backend/src/domain/posts/value_objects/post_cursor.py`
- [X] T011 [P] Define API DTO mappers for `PostResponse`/`AttachmentResponse` in `backend/src/adapters/api/v1/posts.py`
- [X] T012 [P] Define attachment signer port interface in `backend/src/application/ports/attachment_url_signer.py`
- [X] T013 [P] Implement default Nginx signer adapter in `backend/src/adapters/security/nginx_secure_link_signer.py`
- [X] T014 [P] Implement CloudFront signer adapter in `backend/src/adapters/security/cloudfront_signed_url_signer.py`
- [X] T015 Implement hybrid provider resolution (default + per-attachment override) in `backend/src/application/use_cases/list_posts.py`

**Checkpoint**: Foundation ready; user stories can proceed.

---

## Phase 3: User Story 1 - Create Post (Priority: P1) 🎯 MVP

**Goal**: Authenticated user creates a post with validated privacy and receives created resource payload.

**Independent Test**: `POST /v1/posts` returns `201` with `id`, `user_id`, `privacy`, `attachments`, and timestamps; invalid privacy returns `422`; unauthenticated returns `401`.

### Tests for User Story 1

- [X] T016 [P] [US1] Add `POST /v1/posts` success/error contract tests in `backend/tests/contract/test_posts_contract.py`
- [X] T017 [P] [US1] Add create-post integration tests for DB persistence in `backend/tests/integration/test_posts_integration.py`
- [X] T018 [P] [US1] Add create-post use-case unit tests in `backend/tests/unit/test_posts_use_cases.py`

### Implementation for User Story 1

- [X] T019 [US1] Implement `CreatePostUseCase` with privacy validation and authenticated author assignment in `backend/src/application/use_cases/create_post.py`
- [X] T020 [US1] Implement `POST /v1/posts` adapter endpoint and response wiring in `backend/src/adapters/api/v1/posts.py`
- [X] T021 [US1] Ensure create response includes empty `attachments` array mapping in `backend/src/adapters/api/v1/posts.py`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - List My Own Posts (Priority: P1)

**Goal**: Authenticated user lists only their own posts using stable cursor pagination.

**Independent Test**: `GET /v1/me/posts` returns only posts where `user_id == current_user.id`, sorted by `created_at DESC, id DESC`, with cursor pagination.

### Tests for User Story 2

- [X] T022 [P] [US2] Add `GET /v1/me/posts` contract tests (including pagination + empty list) in `backend/tests/contract/test_posts_contract.py`
- [X] T023 [P] [US2] Add my-posts integration tests for filtering and ordering in `backend/tests/integration/test_posts_integration.py`
- [X] T024 [P] [US2] Add my-posts use-case unit tests for cursor behavior in `backend/tests/unit/test_posts_use_cases.py`

### Implementation for User Story 2

- [X] T025 [US2] Implement own-post query branch in `ListPostsUseCase` in `backend/src/application/use_cases/list_posts.py`
- [X] T026 [US2] Implement `GET /v1/me/posts` adapter endpoint with `page_size`/`cursor` parameters in `backend/src/adapters/api/v1/posts.py`

**Checkpoint**: User Stories 1 and 2 are independently functional and testable.

---

## Phase 5: User Story 3 - List Specific User Posts (Priority: P2)

**Goal**: Authenticated user lists posts for a specific target user by `{userId}`.

**Independent Test**: `GET /v1/user/{userId}/posts` returns only target user posts; malformed UUID returns `422`.

### Tests for User Story 3

- [X] T027 [P] [US3] Add `GET /v1/user/{userId}/posts` contract tests for success and malformed UUID in `backend/tests/contract/test_posts_contract.py`
- [X] T028 [P] [US3] Add specific-user integration tests for strict author filtering in `backend/tests/integration/test_posts_integration.py`
- [X] T029 [P] [US3] Add use-case unit tests for target-user branch in `backend/tests/unit/test_posts_use_cases.py`

### Implementation for User Story 3

- [X] T030 [US3] Implement specific-user listing query branch in `ListPostsUseCase` in `backend/src/application/use_cases/list_posts.py`
- [X] T031 [US3] Implement `GET /v1/user/{userId}/posts` adapter endpoint and path validation wiring in `backend/src/adapters/api/v1/posts.py`

**Checkpoint**: User Stories 1, 2, and 3 are independently functional and testable.

---

## Phase 6: User Story 4 - List Following Feed (Priority: P2)

**Goal**: Authenticated user lists posts authored by accepted friend/follow relations.

**Independent Test**: `GET /v1/posts` returns only followed users' posts; non-followed users are excluded; empty feed returns `200` with empty items.

### Tests for User Story 4

- [X] T032 [P] [US4] Add `GET /v1/posts` following-feed contract tests in `backend/tests/contract/test_posts_contract.py`
- [X] T033 [P] [US4] Add following-feed integration tests for accepted friend relation filtering in `backend/tests/integration/test_posts_integration.py`
- [X] T034 [P] [US4] Add following-feed use-case unit tests for relation resolution in `backend/tests/unit/test_posts_use_cases.py`

### Implementation for User Story 4

- [X] T035 [US4] Implement following-feed author resolution from accepted friend relations in `backend/src/application/use_cases/list_posts.py`
- [X] T036 [US4] Implement `GET /v1/posts` adapter endpoint branch in `backend/src/adapters/api/v1/posts.py`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Finalize cross-story quality gates, docs alignment, and performance/security checks.

- [X] T037 [P] Add integration assertions for typed attachment payloads and no subtype-table joins in `backend/tests/integration/test_posts_integration.py`
- [X] T038 [P] Add contract assertions for attachment object variants in `backend/tests/contract/test_posts_contract.py`
- [X] T039 Regenerate and verify OpenAPI includes `/v1/posts`, `/v1/me/posts`, `/v1/user/{userId}/posts` in `backend/openapi.json`
- [X] T040 Run backend quality gate commands from `specs/005-posts-create-list-endpoints/quickstart.md` and record outcomes in `specs/005-posts-create-list-endpoints/validation.md`
- [X] T041 [P] Add contract coverage for default `nginx_secure_link`, CloudFront override, and fail-closed responses in `backend/tests/contract/test_posts_contract.py`
- [X] T042 [P] Add integration coverage for signed URL expiry at `5m` and provider override behavior in `backend/tests/integration/test_posts_integration.py`
- [X] T043 Measure and record `GET`/`POST` p95 latency against targets (GET <= 200ms, POST <= 500ms) in `specs/005-posts-create-list-endpoints/validation.md`
- [X] T044 Add query-log review for `/v1/posts`, `/v1/me/posts`, and `/v1/user/{userId}/posts` to verify no N+1 patterns in `specs/005-posts-create-list-endpoints/validation.md`
- [X] T045 [P] Add unit coverage for provider selection and signing failure handling in `backend/tests/unit/test_posts_use_cases.py`
- [X] T046 Verify unit test coverage is 100% for feature-touched use-case/service logic in `backend/tests/unit/test_posts_use_cases.py`
- [X] T047 Capture TDD evidence (failing test first, minimal implementation, passing test) for each completed task in `specs/005-posts-create-list-endpoints/validation.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: no dependencies.
- **Phase 2 (Foundational)**: depends on Phase 1; blocks all user stories.
- **Phase 3+ (User Stories)**: depend on Phase 2 completion.
- **Phase 7 (Polish)**: depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: starts immediately after foundational phase.
- **US2 (P1)**: starts after foundational phase; independent from US1 behavior.
- **US3 (P2)**: starts after foundational phase; independent from US1/US2 behavior.
- **US4 (P2)**: starts after foundational phase; independent from US1/US2/US3 behavior.

### Within Each User Story

- Tests first (must fail), then implementation.
- Keep changes in short red-green-refactor cycles per task.
- Service logic before endpoint wiring.
- Endpoint implementation before final story validation.

### Parallel Opportunities

- `[P]` tasks in Phase 1 and Phase 2 can run concurrently.
- For each story, contract/integration/unit tests can be authored in parallel.
- After foundational completion, US1-US4 can be implemented in parallel by separate developers.

---

## Parallel Example: User Story 1

```bash
Task: "T016 [US1] Add POST contract tests in backend/tests/contract/test_posts_contract.py"
Task: "T017 [US1] Add create integration tests in backend/tests/integration/test_posts_integration.py"
Task: "T018 [US1] Add create unit tests in backend/tests/unit/test_posts_use_cases.py"
```

## Parallel Example: User Story 2

```bash
Task: "T022 [US2] Add my-posts contract tests in backend/tests/contract/test_posts_contract.py"
Task: "T023 [US2] Add my-posts integration tests in backend/tests/integration/test_posts_integration.py"
Task: "T024 [US2] Add my-posts unit tests in backend/tests/unit/test_posts_use_cases.py"
```

## Parallel Example: User Story 3

```bash
Task: "T027 [US3] Add specific-user contract tests in backend/tests/contract/test_posts_contract.py"
Task: "T028 [US3] Add specific-user integration tests in backend/tests/integration/test_posts_integration.py"
Task: "T029 [US3] Add specific-user unit tests in backend/tests/unit/test_posts_use_cases.py"
```

## Parallel Example: User Story 4

```bash
Task: "T032 [US4] Add following-feed contract tests in backend/tests/contract/test_posts_contract.py"
Task: "T033 [US4] Add following-feed integration tests in backend/tests/integration/test_posts_integration.py"
Task: "T034 [US4] Add following-feed unit tests in backend/tests/unit/test_posts_use_cases.py"
```

---

## Implementation Strategy

### MVP First (US1 only)

1. Complete Phase 1 and Phase 2.
2. Complete Phase 3 (US1).
3. Validate `POST /v1/posts` contract/integration/unit tests.
4. Demo MVP create-post flow.

### Incremental Delivery

1. Foundation complete (Phases 1-2).
2. Deliver US1 (create post).
3. Deliver US2 (my posts).
4. Deliver US3 (specific user posts).
5. Deliver US4 (following feed).
6. Finish polish phase and full quality gates.

### Parallel Team Strategy

1. Team aligns on foundational schema/migration and shared API models.
2. After Phase 2, assign stories by owner:
   - Dev A: US1
   - Dev B: US2
   - Dev C: US3
   - Dev D: US4
3. Merge stories independently once each independent test criterion passes.
