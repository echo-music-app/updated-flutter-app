# Tasks: Mobile Profile Viewing

**Input**: Design documents from `/specs/009-mobile-profile-view/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/mobile-profile-view.md`, `quickstart.md`

**Tests**: Included — this feature plan explicitly requires strict test-first red/green/refactor using unit, widget, and integration tests.

**Organization**: Tasks are grouped by user story so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: User-story label (`[US1]`, `[US2]`, `[US3]`)
- Every task includes exact file path(s)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature scaffolding and test entry points.

- [X] T001 Create profile feature scaffolds in `mobile/lib/features/profile_view/domain/entities/profile.dart`, `mobile/lib/features/profile_view/domain/entities/profile_posts_page.dart`, `mobile/lib/features/profile_view/domain/use_cases/resolve_profile_target.dart`, `mobile/lib/features/profile_view/domain/use_cases/load_profile_header.dart`, `mobile/lib/features/profile_view/domain/use_cases/load_profile_posts_page.dart`, `mobile/lib/features/profile_view/domain/ports/profile_repository.dart`, `mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart`, `mobile/lib/features/profile_view/presentation/profile_view_model.dart`, `mobile/lib/features/profile_view/presentation/profile_screen.dart`, `mobile/lib/features/profile_view/presentation/widgets/profile_header.dart`, and `mobile/lib/features/profile_view/presentation/widgets/profile_posts_list.dart`
- [X] T002 [P] Create unit test scaffolds in `mobile/test/unit/features/profile_view/profile_use_cases_test.dart`, `mobile/test/unit/features/profile_view/profile_view_model_test.dart`, and `mobile/test/unit/features/profile_view/profile_repository_test.dart`
- [X] T003 [P] Create widget test scaffolds in `mobile/test/widget/features/profile_view/profile_screen_test.dart` and `mobile/test/widget/features/profile_view/profile_posts_list_test.dart`
- [X] T004 [P] Create integration test scaffold in `mobile/integration_test/profile_flow_test.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared profile-view foundations required by all user stories.

**⚠️ CRITICAL**: No user story implementation starts until this phase is complete.

- [X] T005 [P] Add failing unit tests for foundational use-case behavior (route target resolution, auth/not-found decisions) in `mobile/test/unit/features/profile_view/profile_use_cases_test.dart`
- [X] T006 Define profile route/header domain entities (`ProfileMode`, `ProfileRouteTarget`, `ProfileHeader`, `ProfileImageState`) in `mobile/lib/features/profile_view/domain/entities/profile.dart`
- [X] T007 [P] Define paginated post entities (`ProfilePostSummary`, `ProfilePostsPage`) in `mobile/lib/features/profile_view/domain/entities/profile_posts_page.dart`
- [X] T008 [P] Define profile repository contract methods and error/result contracts for own/other profile + paged posts in `mobile/lib/features/profile_view/domain/ports/profile_repository.dart`
- [X] T009 Implement profile domain use cases (`ResolveProfileTargetUseCase`, `LoadProfileHeaderUseCase`, `LoadProfilePostsPageUseCase`) in `mobile/lib/features/profile_view/domain/use_cases/resolve_profile_target.dart`, `mobile/lib/features/profile_view/domain/use_cases/load_profile_header.dart`, and `mobile/lib/features/profile_view/domain/use_cases/load_profile_posts_page.dart`
- [X] T010 [P] Implement repository base wiring (authenticated `dio` calls, endpoint path builders, shared error translation helpers) in `mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart`
- [X] T011 [P] Register `ProfileRepository` and domain use-case dependency wiring in `mobile/lib/config/dependencies.dart`
- [X] T012 [P] Add profile route constants in `mobile/lib/routing/routes.dart`
- [X] T013 Implement profile route skeleton and dependency injection wiring in `mobile/lib/routing/app_router.dart`
- [X] T014 Implement shared profile screen presentation-state primitives in `mobile/lib/features/profile_view/presentation/profile_view_model.dart`, delegating business rules to domain use cases
- [X] T015 [P] Add foundational profile localization keys in `mobile/lib/l10n/app_en.arb`

**Checkpoint**: Shared foundation (including use-case layer) is complete; user stories can begin.

---

## Phase 3: User Story 1 - View Own Profile (Priority: P1) 

**Goal**: Authenticated user can open own profile and see placeholder image, bio, genres, and own posts with proper loading/empty/error states.

**Independent Test**: Sign in, open `/profile`, and validate own-profile sections plus state handling (`loading`, `empty`, `error`, `data`) without route-target ambiguity.

### Tests for User Story 1

- [X] T016 [P] [US1] Add unit tests for own-mode state transitions (`loading/data/empty/error/auth_required`) in `mobile/test/unit/features/profile_view/profile_view_model_test.dart`
- [X] T017 [P] [US1] Add repository tests for `GET /v1/me` and `GET /v1/me/posts` mapping including `401/403` translation in `mobile/test/unit/features/profile_view/profile_repository_test.dart`
- [X] T018 [P] [US1] Add use-case tests for own-profile header/posts loading branches in `mobile/test/unit/features/profile_view/profile_use_cases_test.dart`
- [X] T019 [P] [US1] Add widget tests for own-profile loading/empty/error/data/auth_required rendering in `mobile/test/widget/features/profile_view/profile_screen_test.dart`
- [X] T020 [P] [US1] Add integration tests for own-profile flow and expired-session re-auth behavior on `/profile` in `mobile/integration_test/profile_flow_test.dart`

### Implementation for User Story 1

- [X] T021 [US1] Implement own-profile repository methods (`/v1/me`, `/v1/me/posts`) with auth/session-expired and error translation in `mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart`
- [X] T022 [US1] Implement own-mode logic in `LoadProfileHeaderUseCase` and `LoadProfilePostsPageUseCase` in `mobile/lib/features/profile_view/domain/use_cases/load_profile_header.dart` and `mobile/lib/features/profile_view/domain/use_cases/load_profile_posts_page.dart`
- [X] T023 [US1] Implement own-mode orchestration, retry flows, and stale-content clearing on auth expiry in `mobile/lib/features/profile_view/presentation/profile_view_model.dart`
- [X] T024 [US1] Implement profile header UI (placeholder avatar, bio section, genres section) in `mobile/lib/features/profile_view/presentation/widgets/profile_header.dart`
- [X] T025 [US1] Implement own-profile screen composition with section-level states and re-auth prompt state in `mobile/lib/features/profile_view/presentation/profile_screen.dart`
- [X] T026 [US1] Wire `/profile` route to `ProfileScreen` + `ProfileViewModel` in `mobile/lib/routing/app_router.dart`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - View Another User Profile (Priority: P1)

**Goal**: Authenticated user can open another user's profile with public profile data, public-only posts, not-found behavior, and self-route normalization.

**Independent Test**: Navigate to `/profile/:userId` for existing, missing, and self IDs and verify correct mode, data visibility, and error/`not_found` handling.

### Tests for User Story 2

- [X] T027 [P] [US2] Add use-case tests for self-id normalization and other-mode route target resolution in `mobile/test/unit/features/profile_view/profile_use_cases_test.dart`
- [X] T028 [P] [US2] Add repository tests for `GET /v1/users/{userId}` and `GET /v1/user/{userId}/posts` including `401/404/422` mapping in `mobile/test/unit/features/profile_view/profile_repository_test.dart`
- [X] T029 [P] [US2] Add unit tests for other-mode transitions, self-normalization behavior, and stale-data clearing in `mobile/test/unit/features/profile_view/profile_view_model_test.dart`
- [X] T030 [P] [US2] Add widget tests for other-profile `data/not_found/error/auth_required` states in `mobile/test/widget/features/profile_view/profile_screen_test.dart` (explicit mode-indicator assertions are covered by `T058`)
- [X] T031 [P] [US2] Add integration tests for `/profile/:userId` existing/missing/self and expired-session behavior in `mobile/integration_test/profile_flow_test.dart`

### Implementation for User Story 2

- [X] T032 [US2] Implement other-profile repository methods with public-only post consumption and `401/404/422` translation in `mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart`
- [X] T033 [US2] Implement self-route normalization logic in `ResolveProfileTargetUseCase` in `mobile/lib/features/profile_view/domain/use_cases/resolve_profile_target.dart`
- [X] T034 [US2] Implement other-mode header decision branches in `LoadProfileHeaderUseCase` in `mobile/lib/features/profile_view/domain/use_cases/load_profile_header.dart`
- [X] T035 [US2] Implement mode switching, self-route normalization behavior, and auth-expiry handling in `mobile/lib/features/profile_view/presentation/profile_view_model.dart`
- [X] T036 [US2] Implement `/profile/:userId` route parsing and parameter validation wiring in `mobile/lib/routing/app_router.dart`
- [X] T037 [US2] Update profile route constants for parameterized user-profile path in `mobile/lib/routing/routes.dart`
- [X] T038 [US2] Implement own-vs-other mode indicator/title (`myProfileTitle` vs `userProfileTitle`) and not-found rendering in `mobile/lib/features/profile_view/presentation/profile_screen.dart`

**Checkpoint**: User Stories 1 and 2 are independently functional and testable.

---

## Phase 5: User Story 3 - Browse Profile Posts (Priority: P2)

**Goal**: User can browse profile posts with cursor pagination, load-more append behavior, and posts-only error handling while preserving header visibility.

**Independent Test**: Open profile with multiple pages of posts, trigger load-more, and validate append behavior plus posts-error handling without losing header content.

### Tests for User Story 3

- [X] T039 [P] [US3] Add use-case tests for cursor pagination, next-cursor propagation, and load-more retry policy in `mobile/test/unit/features/profile_view/profile_use_cases_test.dart`
- [X] T040 [P] [US3] Add unit tests for append-without-replace and header-visible-on-posts-error behavior in `mobile/test/unit/features/profile_view/profile_view_model_test.dart`
- [X] T041 [P] [US3] Add widget tests for posts list load-more/append/error states in `mobile/test/widget/features/profile_view/profile_posts_list_test.dart`
- [X] T042 [P] [US3] Add integration test for multi-page profile-post browsing and header persistence in `mobile/integration_test/profile_flow_test.dart`

### Implementation for User Story 3

- [X] T043 [US3] Implement cursor/page-size pagination methods and next-cursor propagation in `mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart`
- [X] T044 [US3] Implement paginated loading and retry policy in `LoadProfilePostsPageUseCase` in `mobile/lib/features/profile_view/domain/use_cases/load_profile_posts_page.dart`
- [X] T045 [US3] Implement load-more state machine and append-without-replace behavior in `mobile/lib/features/profile_view/presentation/profile_view_model.dart`
- [X] T046 [US3] Implement paginated posts list UI with load-more/retry controls in `mobile/lib/features/profile_view/presentation/widgets/profile_posts_list.dart`
- [X] T047 [US3] Integrate posts pagination widget into profile screen with posts-section error isolation in `mobile/lib/features/profile_view/presentation/profile_screen.dart`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize localization, accessibility, dark-mode compliance, and quality/performance evidence.

- [X] T048 [P] Audit and finalize profile localization keys and action labels in `mobile/lib/l10n/app_en.arb`
- [X] T049 Regenerate localization outputs and update profile string references in `mobile/lib/generated/l10n/app_localizations.dart` and `mobile/lib/generated/l10n/app_localizations_en.dart`
- [X] T050 [P] Add/verify semantics labels for placeholder avatar and retry/load-more actions in `mobile/lib/features/profile_view/presentation/widgets/profile_header.dart`, `mobile/lib/features/profile_view/presentation/widgets/profile_posts_list.dart`, and `mobile/lib/features/profile_view/presentation/profile_screen.dart`
- [X] T051 [P] Add dark/light mode widget coverage for profile screen and posts list in `mobile/test/widget/features/profile_view/profile_screen_test.dart` and `mobile/test/widget/features/profile_view/profile_posts_list_test.dart`
- [X] T052 [P] Add rapid-profile-switch and stale-response regression coverage in `mobile/test/unit/features/profile_view/profile_view_model_test.dart` and `mobile/integration_test/profile_flow_test.dart`
- [X] T053 Run `dart format --set-exit-if-changed .`, `flutter analyze`, `flutter test`, and `flutter test integration_test/profile_flow_test.dart` from `mobile/`; record outcomes in `specs/009-mobile-profile-view/quickstart.md`
- [X] T054 [P] Reconcile final behavior notes for route normalization, auth-expiry handling, and pagination in `specs/009-mobile-profile-view/contracts/mobile-profile-view.md` and `specs/009-mobile-profile-view/quickstart.md`
- [ ] T055 Add SC-002 profile-header latency measurement scenario using the SC-002 baseline test profile in `mobile/integration_test/profile_flow_test.dart` and record benchmark evidence in `specs/009-mobile-profile-view/quickstart.md` (100 profile navigations; pass if `>=95` render core profile header in `<=2.0s`)
- [ ] T056 Add SC-003 cross-user correctness measurement in `mobile/integration_test/profile_flow_test.dart` and record outcomes in `specs/009-mobile-profile-view/quickstart.md` (100 profile navigations; pass if `>=95%` show correct target user and zero stale cross-user render defects)
- [ ] T057 Add SC-005 product acceptance sample outcomes and own-vs-other mode identification success rate in `specs/009-mobile-profile-view/quickstart.md` (>=20 scenarios/users; target `>=90%`)
- [X] T058 [P] Add explicit mode-indicator assertions (`myProfileTitle` vs `userProfileTitle` with username) in `mobile/test/widget/features/profile_view/profile_screen_test.dart` and `mobile/integration_test/profile_flow_test.dart`
- [ ] T059 Run Flutter profile-mode performance validation for `/profile` and `/profile/:userId` on SC-002 baseline devices, capture FPS and frame-jank (`>16ms`) evidence in `specs/009-mobile-profile-view/quickstart.md`, and fail validation if 60 fps target is not met

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Depends on Phase 2 only; implementation may touch shared files with US1 and requires merge coordination.
- **Phase 5 (US3)**: Depends on Phase 2 and profile-screen baseline from US1 (and benefits from US2 route-complete behavior).
- **Phase 6 (Polish)**: Depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: First deliverable after foundational work.
- **US2 (P1)**: Can start after Phase 2 and remains independently testable; coordinate shared-file merges with US1.
- **US3 (P2)**: Builds on profile baseline and pagination-specific logic; remains independently testable.
- **US1 + US2**: Can proceed in parallel after Phase 2 when team capacity allows.

### Within Each User Story

- Write tests first and confirm they fail.
- Implement repository/domain logic before view-model orchestration.
- Implement view-model logic before final screen/widget wiring.
- Re-run story-specific unit/widget/integration tests before moving on.

### Parallel Opportunities

- Setup tasks `T002`–`T004` can run in parallel.
- Foundational `[P]` tasks (`T005`, `T007`, `T008`, `T010`, `T011`, `T012`, `T015`) can run in parallel after scaffolding.
- Per story, test tasks marked `[P]` can run in parallel.
- Polish `[P]` tasks (`T048`, `T050`, `T051`, `T052`, `T054`, `T058`) can run in parallel.
- In implementation phases, tasks touching different files (`profile_header.dart` vs `echo_profile_repository.dart` vs tests) can run in parallel where dependencies permit.

---

## Parallel Example: User Story 1

```bash
Task: "T016 [US1] Unit tests in mobile/test/unit/features/profile_view/profile_view_model_test.dart"
Task: "T017 [US1] Repository tests in mobile/test/unit/features/profile_view/profile_repository_test.dart"
Task: "T019 [US1] Widget tests in mobile/test/widget/features/profile_view/profile_screen_test.dart"
Task: "T020 [US1] Integration test in mobile/integration_test/profile_flow_test.dart"
```

## Parallel Example: User Story 2

```bash
Task: "T027 [US2] Route-target use-case tests in mobile/test/unit/features/profile_view/profile_use_cases_test.dart"
Task: "T028 [US2] Repository endpoint mapping tests in mobile/test/unit/features/profile_view/profile_repository_test.dart"
Task: "T030 [US2] Other-profile widget tests in mobile/test/widget/features/profile_view/profile_screen_test.dart"
Task: "T031 [US2] Route normalization integration tests in mobile/integration_test/profile_flow_test.dart"
```

## Parallel Example: User Story 3

```bash
Task: "T039 [US3] Pagination use-case tests in mobile/test/unit/features/profile_view/profile_use_cases_test.dart"
Task: "T040 [US3] Pagination append unit tests in mobile/test/unit/features/profile_view/profile_view_model_test.dart"
Task: "T041 [US3] Posts list widget tests in mobile/test/widget/features/profile_view/profile_posts_list_test.dart"
Task: "T042 [US3] Pagination integration test in mobile/integration_test/profile_flow_test.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. Validate own-profile experience independently.
5. Demo/deploy MVP profile view.

### Incremental Delivery

1. Foundation complete (Phases 1–2).
2. Deliver US1 (`/profile` own mode).
3. Deliver US2 (`/profile/:userId`, not-found, self-normalization).
4. Deliver US3 (paged posts browsing and section-isolated errors).
5. Complete Phase 6 polish and quality gates.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. After foundational completion:
   - Developer A: US1 own-profile flow
   - Developer B: US2 other-profile flow and routing
   - Developer C: US3 pagination and posts widget behavior
3. Merge each story after independent test criteria pass.
