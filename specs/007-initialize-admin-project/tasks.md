# Tasks: Initialize Admin UI Project

**Input**: Design documents from `/specs/007-initialize-admin-project/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/admin-ui.md, quickstart.md

**Tests**: Tests are required for this feature by the constitution and the implementation plan. Write tests first and ensure they fail before implementation.

**Organization**: Tasks are grouped by user story so each story can be implemented and validated independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (`[US1]`, `[US2]`, `[US3]`, `[US4]`)
- Every task includes exact file paths
- Letter suffixes (for example, `T022A`) preserve stable task ordering when remediation tasks are inserted

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Initialize the browser-based admin app and its local tooling.

- [x] T001 Create the admin project manifests in `admin/package.json` (including `"engines": {"node": ">=24"}` and `"packageManager": "pnpm@latest"`), `admin/tsconfig.json`, `admin/vite.config.ts`, `admin/index.html`, and `admin/.nvmrc` (pinned to `24`)
- [x] T002 Configure styling and component tooling in `admin/tailwind.config.ts`, `admin/postcss.config.mjs`, and `admin/components.json`
- [x] T003 [P] Configure code quality and frontend test runners in `admin/biome.json` (include a `complexity` rule to flag functions exceeding 40 lines, matching the constitution Principle I limit), `admin/vitest.config.ts`, and `admin/playwright.config.ts`
- [x] T004 [P] Create the app bootstrap and providers in `admin/src/app/main.tsx`, `admin/src/app/providers/query-client.tsx`, `admin/src/app/providers/theme-provider.tsx`, and `admin/src/core/config/env.ts`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core backend/frontend infrastructure that MUST exist before any user story is implemented.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 [P] Add backend foundation tests for admin dependencies and audit persistence in `backend/tests/integration/core/test_admin_deps.py` and `backend/tests/integration/infrastructure/test_admin_action_repository.py`
- [x] T005A [P] Add backend unit tests for admin audit and admin dependency use cases in `backend/tests/unit/application/test_admin_audit.py` and `backend/tests/unit/infrastructure/test_admin_deps.py`
- [x] T006 [P] Add frontend foundation tests for route guards and shared API utilities in `admin/tests/component/app/router-shell.test.tsx` and `admin/tests/unit/core/http-client.test.ts`
- [x] T007 Create admin persistence models and migration in `backend/src/backend/infrastructure/persistence/models/admin.py` (includes `AdminAccount` with a boolean `is_active` flag and a `permission_scope` enum column representing the single broad `AdminPermissionSet` — no separate permission table), `backend/src/backend/infrastructure/persistence/models/admin_action.py`, and `backend/migrations/versions/007_admin_project.py`
- [x] T008 [P] Implement admin persistence repositories in `backend/src/backend/infrastructure/persistence/repositories/admin_repository.py` and `backend/src/backend/infrastructure/persistence/repositories/admin_action_repository.py`
- [x] T009 [P] Implement admin auth dependency wiring in `backend/src/backend/core/admin_deps.py` and implement the admin audit use case in `backend/src/backend/application/use_cases/admin_audit.py` (dependency wiring only in `core/`; all audit logic in `application/use_cases/`); the audit use case MUST record an `AdminAction` for every `/admin/v1` operation outcome — successful, explicitly denied (message boundary), and authorization failures (non-admin or inactive token) — with an empty diff for non-mutating and denied operations
- [x] T010 [P] Register the admin API package in `backend/src/backend/presentation/api/v1/admin/__init__.py` and `backend/src/backend/presentation/api/v1/__init__.py`
- [x] T011 [P] Create shared frontend API and routing utilities in `admin/src/core/api/http-client.ts`, `admin/src/core/api/query-keys.ts`, `admin/src/core/auth/route-guard.tsx`, and `admin/src/core/routing/route-definitions.ts`
- [x] T012 [P] Create the shared admin shell and reusable UI primitives in `admin/src/shared/layout/app-shell.tsx`, `admin/src/shared/forms/admin-action-form.tsx`, `admin/src/shared/table/data-table.tsx`, and `admin/src/shared/ui/empty-state.tsx`

**Checkpoint**: Foundation ready - user story implementation can now begin.

---

## Phase 3: User Story 1 - Access Dedicated Admin Workspace (Priority: P1) 🎯 MVP

**Goal**: Allow active admins to sign in to a dedicated admin workspace while denying non-admin and disabled accounts.

**Independent Test**: Verify an active admin can sign in and reach the protected shell, while non-admin and disabled accounts are denied across the UI and `/admin/v1` backend surface.

### Tests for User Story 1 ⚠️

- [x] T013 [P] [US1] Add backend contract tests for admin sign-in, session bootstrap, and logout in `backend/tests/contract/test_admin_auth.py`
- [x] T014 [P] [US1] Add backend integration tests for active, non-admin, and disabled admin access in `backend/tests/integration/presentation/api/v1/test_admin_auth.py`; MUST include a scenario where an admin account is disabled while an active session exists and the next request is rejected
- [x] T014A [P] [US1] Add backend unit tests for admin auth use cases in `backend/tests/unit/application/test_admin_auth.py`
- [x] T015 [P] [US1] Add admin UI login and route-protection tests in `admin/tests/component/auth/login-page.test.tsx` and `admin/tests/e2e/auth/admin-auth.spec.ts`

### Implementation for User Story 1

- [x] T016 [P] [US1] Implement admin auth domain and use cases in `backend/src/backend/domain/admin_auth/entities.py`, `backend/src/backend/domain/admin_auth/exceptions.py`, and `backend/src/backend/application/use_cases/admin_auth.py`
- [x] T017 [US1] Implement admin auth endpoints and session DTOs in `backend/src/backend/presentation/api/v1/admin/auth.py`; sign-in and logout handlers MUST call the audit use case from T009 to emit an `AdminAction` record for each auth event
- [x] T018 [P] [US1] Implement frontend admin auth data and entities in `admin/src/features/auth/data/admin-auth-api.ts` and `admin/src/features/auth/domain/entities/admin-session.ts`
- [x] T019 [US1] Implement the login page and authenticated admin shell in `admin/src/features/auth/presentation/login-page.tsx` and `admin/src/features/auth/presentation/session-shell.tsx`
- [x] T020 [US1] Wire protected admin routes and the landing dashboard in `admin/src/app/router/index.tsx` and `admin/src/features/dashboard/presentation/dashboard-page.tsx`

**Checkpoint**: User Story 1 should be fully functional and independently testable.

---

## Phase 4: User Story 2 - Manage Users and User-Owned Content (Priority: P1)

**Goal**: Let administrators find users, change reversible user status, moderate user-owned content, and surface persisted `AdminAction` feedback.

**Independent Test**: Verify an authenticated admin can search for a user, change account status, moderate content, see the resulting state, and receive auditable action feedback.

### Tests for User Story 2 ⚠️

- [x] T021 [P] [US2] Add backend contract tests for admin user and content endpoints in `backend/tests/contract/test_admin_users_and_content.py`
- [x] T022 [P] [US2] Add backend integration tests for user status changes and content moderation in `backend/tests/integration/presentation/api/v1/test_admin_users_and_content.py`
- [x] T022A [P] [US2] Add backend unit tests for admin user moderation use cases in `backend/tests/unit/application/test_admin_users.py`
- [x] T022B [P] [US2] Add backend unit tests for admin content moderation use cases in `backend/tests/unit/application/test_admin_content.py`
- [x] T022C [P] [US2] Add backend integration tests for deterministic conflict handling during concurrent moderation updates in `backend/tests/integration/presentation/api/v1/test_admin_concurrency.py`
- [x] T023 [P] [US2] Add admin UI moderation tests for user and content flows in `admin/tests/component/users/user-moderation.test.tsx`, `admin/tests/component/content/content-moderation.test.tsx`, and `admin/tests/e2e/moderation/users-and-content.spec.ts`

### Implementation for User Story 2

- [x] T024 [P] [US2] Implement admin user query and moderation use cases that return managed admin-facing user entities in `backend/src/backend/application/use_cases/admin_users.py` and `backend/src/backend/infrastructure/persistence/repositories/admin_repository.py`
- [x] T025 [P] [US2] Implement admin content query and moderation use cases that return managed admin-facing content entities in `backend/src/backend/application/use_cases/admin_content.py` and `backend/src/backend/infrastructure/persistence/repositories/admin_repository.py`
- [x] T025A [US2] Implement deterministic conflict handling for concurrent user and content moderation updates in `backend/src/backend/application/use_cases/admin_users.py` and `backend/src/backend/application/use_cases/admin_content.py`
- [x] T026 [US2] Implement admin user endpoints in `backend/src/backend/presentation/api/v1/admin/users.py`
- [x] T027 [US2] Implement admin content endpoints in `backend/src/backend/presentation/api/v1/admin/content.py`; apply the same anonymization of sensitive fields to `ManagedContent` serialization as T030 does for `ManagedUser` (FR-026, FR-027)
- [x] T028 [P] [US2] Implement user feature data and managed user entities in `admin/src/features/users/data/users-api.ts`, `admin/src/features/users/domain/entities/managed-user.ts`, and `admin/src/features/users/domain/use_cases/use-user-moderation.ts`
- [x] T029 [P] [US2] Implement content feature data and managed content entities in `admin/src/features/content/data/content-api.ts`, `admin/src/features/content/domain/entities/managed-content.ts`, and `admin/src/features/content/domain/use_cases/use-content-moderation.ts`
- [x] T030 [US2] Add backend anonymization of sensitive moderation fields before serialization in `backend/src/backend/application/use_cases/admin_users.py` and `backend/src/backend/presentation/api/v1/admin/users.py`
- [x] T031 [US2] Implement user list and detail moderation screens in `admin/src/features/users/presentation/users-list-page.tsx` and `admin/src/features/users/presentation/user-detail-page.tsx`
- [x] T032 [US2] Implement content list and detail moderation screens in `admin/src/features/content/presentation/content-list-page.tsx` and `admin/src/features/content/presentation/content-detail-page.tsx`
- [x] T033 [US2] Surface persisted `AdminAction` feedback and query invalidation in `admin/src/shared/forms/admin-action-form.tsx` and `admin/src/core/api/query-keys.ts`; successful actions MUST display a toast notification (shadcn/ui `Sonner` or equivalent) with a human-readable outcome message; destructive actions MUST require an explicit confirmation dialog before submission (FR-013)

**Checkpoint**: User Stories 1 and 2 should both work independently.

---

## Phase 5: User Story 3 - Enforce Message Privacy Boundary (Priority: P1)

**Goal**: Prevent the admin workspace from exposing any message-management capability while auditing denied attempts.

**Independent Test**: Verify no message routes/actions are visible in the admin UI and any attempted admin message access is denied and auditable.

### Tests for User Story 3 ⚠️

- [x] T034 [P] [US3] Add backend tests for denied admin message access and audit logging in `backend/tests/contract/test_admin_message_privacy.py` and `backend/tests/integration/presentation/api/v1/test_admin_message_privacy.py`
- [x] T035 [P] [US3] Add admin UI tests for absent message navigation and blocked indirect access in `admin/tests/component/navigation/message-boundary.test.tsx` and `admin/tests/e2e/privacy/message-boundary.spec.ts`

### Implementation for User Story 3

- [x] T036 [US3] Implement backend message-boundary denial and `AdminAction` logging in `backend/src/backend/core/admin_deps.py` and `backend/src/backend/application/use_cases/admin_audit.py`
- [x] T037 [US3] Remove message routes from navigation and add blocked-feature handling in `admin/src/shared/layout/app-shell.tsx` and `admin/src/core/routing/route-definitions.ts`
- [x] T038 [US3] Guard indirect message entry points in `admin/src/features/users/presentation/user-detail-page.tsx` and `admin/src/features/content/presentation/content-detail-page.tsx`

**Checkpoint**: User Story 3 should be independently testable without exposing any message-management surface.

---

## Phase 6: User Story 4 - Manage Friend Relationships (Priority: P2)

**Goal**: Let administrators review friend relationships, apply corrective actions, and perform permanent deletions when policy requires it.

**Independent Test**: Verify an authenticated admin can inspect a relationship, remove it or permanently delete it, and see the resulting relationship state with auditable feedback.

### Tests for User Story 4 ⚠️

- [x] T039 [P] [US4] Add backend contract tests for friend relationship review and actions in `backend/tests/contract/test_admin_friend_relationships.py`
- [x] T040 [P] [US4] Add backend integration tests for relationship removal and permanent deletion in `backend/tests/integration/presentation/api/v1/test_admin_friend_relationships.py`
- [x] T040A [P] [US4] Add backend unit tests for friend relationship admin use cases in `backend/tests/unit/application/test_admin_friend_relationships.py`
- [x] T041 [P] [US4] Add admin UI relationship moderation tests in `admin/tests/component/friend-relationships/friend-relationships.test.tsx` and `admin/tests/e2e/moderation/friend-relationships.spec.ts`

### Implementation for User Story 4

- [x] T042 [P] [US4] Implement friend relationship admin domain and use cases in `backend/src/backend/domain/admin_friend_relationships/entities.py` and `backend/src/backend/application/use_cases/admin_friend_relationships.py`
- [x] T043 [US4] Implement friend relationship admin endpoints in `backend/src/backend/presentation/api/v1/admin/friend_relationships.py`
- [x] T044 [P] [US4] Implement friend relationship feature data and domain modules in `admin/src/features/friend-relationships/data/friend-relationships-api.ts` and `admin/src/features/friend-relationships/domain/entities/friend-relationship.ts`
- [x] T045 [US4] Implement relationship list and detail moderation screens in `admin/src/features/friend-relationships/presentation/relationship-list-page.tsx` and `admin/src/features/friend-relationships/presentation/relationship-detail-page.tsx`

**Checkpoint**: All user stories should now be independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Finalize shared quality gates, delivery assets, and cross-story refinements.

- [x] T046 [P] Update admin API documentation surfaces in `shared/openapi.json` and `backend/src/backend/presentation/api/v1/__init__.py`
- [x] T047 [P] Add admin CI validation for install, Biome, typecheck, tests, and build in `.github/workflows/ci.yml` and `.github/workflows/cd.yml`; include a basic load-profiling step (e.g., `k6` or `locust` smoke run) against admin GET endpoints to verify p95 latency stays within the constitution Principle V targets (≤200ms GET, ≤500ms write) under expected load
- [x] T048 [P] Optimize route loading and large-table UX in `admin/src/app/router/index.tsx` and `admin/src/shared/table/data-table.tsx`
- [x] T049 Run the full quickstart validation suite and document the verified commands in `specs/007-initialize-admin-project/quickstart.md`; note that SC-003 ("2 min workflow") and SC-004 ("3 min workflow") are pilot-phase operational targets measured post-rollout, not acceptance gates for this feature

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies
- **Phase 2 (Foundational)**: Depends on Phase 1 and blocks all user story work
- **Phase 3 (US1)**: Depends on Phase 2
- **Phase 4 (US2)**: Depends on Phase 2; reuse the authenticated shell from US1 for the UI path
- **Phase 5 (US3)**: Depends on Phase 2; validate against the shared shell and admin audit infrastructure
- **Phase 6 (US4)**: Depends on Phase 2; reuse the authenticated shell and shared moderation primitives
- **Phase 7 (Polish)**: Depends on all implemented stories

### User Story Dependencies

- **US1**: First deliverable and MVP
- **US2**: Backend work can start after Foundation; UI work reuses US1 authentication and shell
- **US3**: Depends on Foundation and should be validated against US1 shell/navigation
- **US4**: Depends on Foundation and can reuse moderation primitives from US2 once available

### Within Each User Story

- Tests MUST be written and fail before implementation
- Backend domain/use-case work precedes endpoint wiring
- Frontend data/domain work precedes page assembly
- Shared feedback and cache invalidation complete before story sign-off

### Parallel Opportunities

- `T003` and `T004` can run in parallel after `T001`/`T002`
- `T005` and `T006` can run in parallel at the start of Phase 2
- `T008` through `T012` can proceed in parallel once `T007` establishes persistence models
- Within each story, backend tests, frontend tests, and data/domain modules marked `[P]` can run in parallel
- After Foundation, backend work for US2, US3, and US4 can be parallelized if the team has capacity

---

## Parallel Example: User Story 1

```bash
Task: "Add backend contract tests for admin sign-in, session bootstrap, and logout in backend/tests/contract/test_admin_auth.py"
Task: "Add backend integration tests for active, non-admin, and disabled admin access in backend/tests/integration/presentation/api/v1/test_admin_auth.py"
Task: "Add admin UI login and route-protection tests in admin/tests/component/auth/login-page.test.tsx and admin/tests/e2e/auth/admin-auth.spec.ts"
```

## Parallel Example: User Story 2

```bash
Task: "Implement admin user query and moderation use cases that return managed admin-facing user entities in backend/src/backend/application/use_cases/admin_users.py and backend/src/backend/infrastructure/persistence/repositories/admin_repository.py"
Task: "Implement admin content query and moderation use cases that return managed admin-facing content entities in backend/src/backend/application/use_cases/admin_content.py and backend/src/backend/infrastructure/persistence/repositories/admin_repository.py"
Task: "Implement user feature data and managed user entities in admin/src/features/users/data/users-api.ts, admin/src/features/users/domain/entities/managed-user.ts, and admin/src/features/users/domain/use_cases/use-user-moderation.ts"
Task: "Implement content feature data and managed content entities in admin/src/features/content/data/content-api.ts, admin/src/features/content/domain/entities/managed-content.ts, and admin/src/features/content/domain/use_cases/use-content-moderation.ts"
```

## Parallel Example: User Story 3

```bash
Task: "Add backend tests for denied admin message access and audit logging in backend/tests/contract/test_admin_message_privacy.py and backend/tests/integration/presentation/api/v1/test_admin_message_privacy.py"
Task: "Add admin UI tests for absent message navigation and blocked indirect access in admin/tests/component/navigation/message-boundary.test.tsx and admin/tests/e2e/privacy/message-boundary.spec.ts"
```

## Parallel Example: User Story 4

```bash
Task: "Add backend contract tests for friend relationship review and actions in backend/tests/contract/test_admin_friend_relationships.py"
Task: "Add backend integration tests for relationship removal and permanent deletion in backend/tests/integration/presentation/api/v1/test_admin_friend_relationships.py"
Task: "Add admin UI relationship moderation tests in admin/tests/component/friend-relationships/friend-relationships.test.tsx and admin/tests/e2e/moderation/friend-relationships.spec.ts"
Task: "Implement friend relationship feature data and domain modules in admin/src/features/friend-relationships/data/friend-relationships-api.ts and admin/src/features/friend-relationships/domain/entities/friend-relationship.ts"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational
3. Complete Phase 3: User Story 1
4. Validate admin sign-in, protected routing, and admin-only access denial
5. Demo the dedicated admin workspace before expanding moderation capabilities

### Incremental Delivery

1. Setup + Foundation establish the admin app, admin persistence, admin auth, and `AdminAction` audit infrastructure
2. Deliver US1 for secure admin access
3. Deliver US2 for user/content moderation
4. Deliver US3 for enforced message privacy boundary
5. Deliver US4 for friend relationship management
6. Finish with OpenAPI, CI, performance, and validation polish

### Parallel Team Strategy

1. One engineer can own backend admin persistence/auth foundation while another scaffolds the admin SPA shell
2. After Foundation, backend/API work for US2-US4 can proceed in parallel with frontend feature module work
3. Keep story sign-off independent by validating each phase against its own tests before moving to the next priority

---

## Notes

- `[P]` tasks touch different files and can be parallelized safely
- Every user story phase includes failing tests before implementation to satisfy the constitution
- `AdminAction` is the only persisted audit/action record for this feature
- User Story 1 is the recommended MVP scope
- Stop at each checkpoint and validate the story independently before continuing
