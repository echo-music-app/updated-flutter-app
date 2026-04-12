# Tasks: Mobile Music Search Screen

**Input**: Design documents from `/specs/010-mobile-search-screen/`
**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/mobile-music-search.md`, `quickstart.md`

**Tests**: Included — this feature plan explicitly requires strict test-first red/green/refactor using unit, widget, and integration tests.

**Organization**: Tasks are grouped by user story so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependency on incomplete tasks)
- **[Story]**: User-story label (`[US1]`, `[US2]`, `[US3]`)
- Every task includes exact file path(s)

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create feature scaffolding and test entry points.

- [X] T001 Create music-search feature scaffolds in `mobile/lib/features/music_search/domain/entities/music_search_result.dart`, `mobile/lib/features/music_search/domain/ports/music_search_repository.dart`, `mobile/lib/features/music_search/domain/use_cases/run_music_search.dart`, `mobile/lib/features/music_search/domain/use_cases/select_search_result_type.dart`, `mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart`, `mobile/lib/features/music_search/presentation/music_search_view_model.dart`, `mobile/lib/features/music_search/presentation/music_search_screen.dart`, `mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart`, `mobile/lib/features/music_search/presentation/widgets/album_search_result_tile.dart`, and `mobile/lib/features/music_search/presentation/widgets/artist_search_result_tile.dart`
- [X] T002 [P] Create unit test scaffolds in `mobile/test/unit/features/music_search/music_search_repository_test.dart`, `mobile/test/unit/features/music_search/run_music_search_use_case_test.dart`, and `mobile/test/unit/features/music_search/music_search_view_model_test.dart`
- [X] T003 [P] Create widget test scaffolds in `mobile/test/widget/features/music_search/music_search_screen_test.dart`, `mobile/test/widget/features/music_search/track_search_result_tile_test.dart`, `mobile/test/widget/features/music_search/album_search_result_tile_test.dart`, and `mobile/test/widget/features/music_search/artist_search_result_tile_test.dart`
- [X] T004 [P] Create integration test scaffold in `mobile/integration_test/music_search_flow_test.dart`
- [X] T005 [P] Add search-entry test scaffold in `mobile/test/widget/home_screen_test.dart`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Build shared search foundations required by all user stories.

**⚠️ CRITICAL**: No user story implementation starts until this phase is complete.

- [X] T006 [P] Add failing foundational tests for `MusicSearchQuery` normalization primitives (trim and whitespace-only invalidation) in `mobile/test/unit/features/music_search/run_music_search_use_case_test.dart`
- [X] T007 Define core domain entities and enums (`MusicSearchQuery`, `SearchResultType`, `ResultAttribution`, typed per-type results, `MusicSearchSummary`, `MusicSearchResultGroup`) in `mobile/lib/features/music_search/domain/entities/music_search_result.dart`
- [X] T008 [P] Define repository interface and typed exception contracts in `mobile/lib/features/music_search/domain/ports/music_search_repository.dart`
- [X] T009 [P] Implement selected-result-type domain rule in `mobile/lib/features/music_search/domain/use_cases/select_search_result_type.dart`
- [X] T010 Implement search use-case core behavior (query normalization, validation, repository delegation) in `mobile/lib/features/music_search/domain/use_cases/run_music_search.dart`
- [X] T011 [P] Implement repository foundation helpers (auth options, response guards, shared error translation) in `mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart`
- [X] T012 [P] Implement foundational search state primitives and notifier plumbing in `mobile/lib/features/music_search/presentation/music_search_view_model.dart`
- [X] T013 [P] Add `Routes.search` constant in `mobile/lib/routing/routes.dart`
- [X] T014 Register `MusicSearchRepository` provider wiring in `mobile/lib/config/dependencies.dart`
- [X] T015 Implement initial `/search` route DI wiring and screen construction in `mobile/lib/routing/app_router.dart`
- [X] T016 [P] Add foundational localization keys for search title/input/actions/states in `mobile/lib/l10n/app_en.arb`

**Checkpoint**: Shared foundation is complete; user stories can begin.

---

## Phase 3: User Story 1 - Search Music with One Query (Priority: P1) 🎯 MVP

**Goal**: Authenticated user can submit one free-text query to `/v1/search/music` (parameter `q`) and view retrieved results with explicit loading/empty/error/auth states.

**Independent Test**: Open `/search`, submit a non-empty term, verify request uses body field `q`, and confirm screen transitions correctly through `loading` to `data` or `empty` without stale results.

### Tests for User Story 1

- [X] T017 [P] [US1] Add repository tests for `POST /v1/search/music` request-body mapping (`q`) and success/error translation (`401` auth-expired mapping, `422`, `503`, network) in `mobile/test/unit/features/music_search/music_search_repository_test.dart`
- [X] T018 [P] [US1] Add use-case tests for valid-query orchestration (forward normalized query to repository) and validation-failure propagation in `mobile/test/unit/features/music_search/run_music_search_use_case_test.dart`
- [X] T019 [P] [US1] Add view-model tests for `idle -> loading -> data/empty/error/authRequired` transitions, retry behavior, and latest-query tracking in `mobile/test/unit/features/music_search/music_search_view_model_test.dart`
- [X] T020 [P] [US1] Add widget tests for query submit, loading state, no-results state, retryable error state, and authRequired state in `mobile/test/widget/features/music_search/music_search_screen_test.dart`
- [X] T021 [P] [US1] Add integration tests for authenticated search submit, no-match behavior, and `401` auth-expired redirect to `/login` in `mobile/integration_test/music_search_flow_test.dart`

### Implementation for User Story 1

- [X] T022 [US1] Implement `POST /v1/search/music` request execution and response decoding in `mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart`
- [X] T023 [US1] Implement typed backend-to-domain mapping for grouped results and summary in `mobile/lib/features/music_search/domain/entities/music_search_result.dart` and `mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart`
- [X] T024 [US1] Implement run-search orchestration and typed result return in `mobile/lib/features/music_search/domain/use_cases/run_music_search.dart`
- [X] T025 [US1] Implement view-model query submission, request-version stale-response protection, retry-last-query behavior, and `401` handling that clears stale results and invokes existing session-clear flow in `mobile/lib/features/music_search/presentation/music_search_view_model.dart`
- [X] T026 [US1] Implement search-screen single free-text input, submit action, and core state rendering in `mobile/lib/features/music_search/presentation/music_search_screen.dart`
- [X] T027 [US1] Finalize `/search` route integration with `MusicSearchViewModel` wiring in `mobile/lib/routing/app_router.dart`
- [X] T028 [US1] Add home-screen navigation entry to `/search` in `mobile/lib/ui/home/home_screen.dart`

**Checkpoint**: User Story 1 is independently functional and testable.

---

## Phase 4: User Story 2 - Filter Results by Type (Priority: P1)

**Goal**: User can switch between `Tracks`, `Albums`, and `Artists` using `SegmentedButton`, viewing only the selected result type without issuing new requests.

**Independent Test**: After one successful search, switch each segment and verify visible list changes by type only, with per-segment empty-state messaging and no additional backend request.

### Tests for User Story 2

- [X] T029 [P] [US2] Add selected-type use-case tests for valid segment transitions in `mobile/test/unit/features/music_search/run_music_search_use_case_test.dart`
- [X] T030 [P] [US2] Add view-model tests ensuring segment switching does not re-query backend and correctly projects per-segment visible results in `mobile/test/unit/features/music_search/music_search_view_model_test.dart`
- [X] T031 [P] [US2] Add widget tests for `SegmentedButton` options (`Tracks`, `Albums`, `Artists`) and single-active selection behavior in `mobile/test/widget/features/music_search/music_search_screen_test.dart`
- [X] T032 [P] [US2] Add integration tests for post-search segment switching and per-segment empty-state behavior in `mobile/integration_test/music_search_flow_test.dart`

### Implementation for User Story 2

- [X] T033 [US2] Implement selected-type transition logic in `mobile/lib/features/music_search/domain/use_cases/select_search_result_type.dart`
- [X] T034 [US2] Integrate selected-type projection and segment-change handling in `mobile/lib/features/music_search/presentation/music_search_view_model.dart`
- [X] T035 [US2] Implement `SegmentedButton` control and selected-segment rendering flow in `mobile/lib/features/music_search/presentation/music_search_screen.dart`
- [X] T036 [US2] Implement per-segment empty-state messages in `mobile/lib/features/music_search/presentation/music_search_screen.dart`
- [X] T037 [US2] Add segment labels and per-segment empty message localization keys in `mobile/lib/l10n/app_en.arb`
- [X] T038 [US2] Regenerate localization outputs in `mobile/lib/generated/l10n/app_localizations.dart` and `mobile/lib/generated/l10n/app_localizations_en.dart`

**Checkpoint**: User Stories 1 and 2 are independently functional and testable.

---

## Phase 5: User Story 3 - View Type-Specific Result Cards (Priority: P2)

**Goal**: Each result type is mapped to typed objects and rendered with dedicated widgets for tracks, albums, and artists.

**Independent Test**: Run a query that returns all result types and verify each segment renders only its dedicated tile widget fed by typed result objects.

### Tests for User Story 3

- [X] T039 [P] [US3] Add repository mapping tests asserting per-type payloads map to distinct typed objects before presentation in `mobile/test/unit/features/music_search/music_search_repository_test.dart`
- [X] T040 [P] [US3] Add widget contract tests for track result tiles in `mobile/test/widget/features/music_search/track_search_result_tile_test.dart`
- [X] T041 [P] [US3] Add widget contract tests for album result tiles in `mobile/test/widget/features/music_search/album_search_result_tile_test.dart`
- [X] T042 [P] [US3] Add widget contract tests for artist result tiles in `mobile/test/widget/features/music_search/artist_search_result_tile_test.dart`
- [X] T043 [P] [US3] Add screen tests verifying each selected segment renders only its dedicated tile widget type in `mobile/test/widget/features/music_search/music_search_screen_test.dart`

### Implementation for User Story 3

- [X] T044 [US3] Implement `TrackSearchResultTile` widget in `mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart`
- [X] T045 [US3] Implement `AlbumSearchResultTile` widget in `mobile/lib/features/music_search/presentation/widgets/album_search_result_tile.dart`
- [X] T046 [US3] Implement `ArtistSearchResultTile` widget in `mobile/lib/features/music_search/presentation/widgets/artist_search_result_tile.dart`
- [X] T047 [US3] Update per-segment list builders to use dedicated tile widgets in `mobile/lib/features/music_search/presentation/music_search_screen.dart`
- [X] T048 [US3] Finalize typed mapping helpers and null-safe defaults for all result types in `mobile/lib/features/music_search/domain/entities/music_search_result.dart` and `mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart`

**Checkpoint**: All user stories are independently functional and testable.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Finalize accessibility, resilience regressions, and quality/performance evidence.

- [X] T049 [P] Add semantics labels for search submit action, segmented controls, retry action, and result tiles in `mobile/lib/features/music_search/presentation/music_search_screen.dart`, `mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart`, `mobile/lib/features/music_search/presentation/widgets/album_search_result_tile.dart`, and `mobile/lib/features/music_search/presentation/widgets/artist_search_result_tile.dart`
- [X] T050 [P] Add localization/accessibility regression widget coverage in `mobile/test/widget/features/music_search/music_search_screen_test.dart`, `mobile/test/widget/features/music_search/track_search_result_tile_test.dart`, `mobile/test/widget/features/music_search/album_search_result_tile_test.dart`, and `mobile/test/widget/features/music_search/artist_search_result_tile_test.dart`
- [X] T051 [P] Add rapid multi-query stale-response regression coverage in `mobile/test/unit/features/music_search/music_search_view_model_test.dart` and `mobile/integration_test/music_search_flow_test.dart`
- [X] T052 [P] Add home-entry navigation regression assertion for `/search` in `mobile/test/widget/home_screen_test.dart`
- [X] T053 Run `dart format --set-exit-if-changed .` from `mobile/` and apply required formatting updates in `mobile/lib/features/music_search/`, `mobile/lib/routing/`, and `mobile/lib/ui/home/home_screen.dart`
- [X] T054 Run `flutter analyze` from `mobile/` and resolve issues in touched files under `mobile/lib/features/music_search/`, `mobile/lib/routing/`, `mobile/lib/config/`, and `mobile/lib/ui/home/home_screen.dart`
- [X] T055 Run `flutter test` from `mobile/` and record outcomes in `specs/010-mobile-search-screen/quickstart.md`
- [ ] T056 Run `flutter test integration_test/music_search_flow_test.dart` from `mobile/` and record outcomes in `specs/010-mobile-search-screen/quickstart.md`
- [ ] T057 Record SC-001 baseline latency evidence (100 submissions, <=2.0s threshold) in `specs/010-mobile-search-screen/quickstart.md`
- [X] T058 [P] Reconcile final contract and quickstart behavior notes (`q` request mapping, segmented filtering, authRequired handling) in `specs/010-mobile-search-screen/contracts/mobile-music-search.md` and `specs/010-mobile-search-screen/quickstart.md`
- [X] T059 [P] Add dark/light mode rendering and contrast assertions for `mobile/lib/features/music_search/presentation/music_search_screen.dart`, `mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart`, `mobile/lib/features/music_search/presentation/widgets/album_search_result_tile.dart`, and `mobile/lib/features/music_search/presentation/widgets/artist_search_result_tile.dart` in `mobile/test/widget/features/music_search/music_search_screen_test.dart`, `mobile/test/widget/features/music_search/track_search_result_tile_test.dart`, `mobile/test/widget/features/music_search/album_search_result_tile_test.dart`, and `mobile/test/widget/features/music_search/artist_search_result_tile_test.dart`
- [ ] T060 Run Flutter search-screen performance validation for `/search` from `mobile/` using `flutter run --profile`, capture FPS and frame-jank (`>16ms`) evidence, and record results in `specs/010-mobile-search-screen/quickstart.md`
- [ ] T061 Define and execute SC-004 first-attempt findability validation using the protocol in `specs/010-mobile-search-screen/quickstart.md` (>=20 representative attempts/users, pass threshold `>=90%`) and record evidence in `specs/010-mobile-search-screen/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies.
- **Phase 2 (Foundational)**: Depends on Phase 1; blocks all user stories.
- **Phase 3 (US1)**: Depends on Phase 2.
- **Phase 4 (US2)**: Depends on Phase 2; implementation is independent, while end-to-end validation reuses US1 baseline query flow.
- **Phase 5 (US3)**: Depends on Phase 2; implementation is independent, while final integrated validation benefits from US1 retrieval and US2 segment wiring.
- **Phase 6 (Polish)**: Depends on completion of desired user stories.

### User Story Dependencies

- **US1 (P1)**: First deliverable after foundational work; no dependency on other stories.
- **US2 (P1)**: Can begin after foundational work and remains independently testable; integration validation can reuse US1 baseline query pipeline.
- **US3 (P2)**: Can begin after foundational work and remains independently testable; integrated validation benefits from US1 retrieval and US2 segment wiring.

### Within Each User Story

- Write tests first and confirm they fail.
- Implement domain/data logic before view-model orchestration.
- Implement view-model orchestration before final screen/widget wiring.
- Re-run story-specific unit/widget/integration tests before moving on.

### Parallel Opportunities

- Setup tasks `T002`–`T005` can run in parallel.
- Foundational `[P]` tasks (`T006`, `T008`, `T009`, `T011`, `T012`, `T013`, `T016`) can run in parallel after scaffolding.
- US1 test tasks `T017`–`T021` can run in parallel.
- US2 test tasks `T029`–`T032` can run in parallel.
- US3 widget-test tasks `T040`–`T043` can run in parallel.
- Polish `[P]` tasks (`T049`, `T050`, `T051`, `T052`, `T058`, `T059`) can run in parallel.

---

## Parallel Example: User Story 1

```bash
Task: "T017 [US1] Repository tests in mobile/test/unit/features/music_search/music_search_repository_test.dart"
Task: "T018 [US1] Use-case tests in mobile/test/unit/features/music_search/run_music_search_use_case_test.dart"
Task: "T020 [US1] Widget tests in mobile/test/widget/features/music_search/music_search_screen_test.dart"
Task: "T021 [US1] Integration tests in mobile/integration_test/music_search_flow_test.dart"
```

## Parallel Example: User Story 2

```bash
Task: "T030 [US2] View-model segment tests in mobile/test/unit/features/music_search/music_search_view_model_test.dart"
Task: "T031 [US2] SegmentedButton widget tests in mobile/test/widget/features/music_search/music_search_screen_test.dart"
Task: "T032 [US2] Segment-switch integration tests in mobile/integration_test/music_search_flow_test.dart"
```

## Parallel Example: User Story 3

```bash
Task: "T040 [US3] Track tile tests in mobile/test/widget/features/music_search/track_search_result_tile_test.dart"
Task: "T041 [US3] Album tile tests in mobile/test/widget/features/music_search/album_search_result_tile_test.dart"
Task: "T042 [US3] Artist tile tests in mobile/test/widget/features/music_search/artist_search_result_tile_test.dart"
Task: "T044 [US3] Track tile implementation in mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 (Setup).
2. Complete Phase 2 (Foundational).
3. Complete Phase 3 (US1).
4. Validate US1 independently using its unit/widget/integration tests.
5. Demo/deploy MVP search flow.

### Incremental Delivery

1. Foundation complete (Phases 1–2).
2. Deliver US1 (single-query retrieval and state handling).
3. Deliver US2 (segmented type filtering without re-query).
4. Deliver US3 (dedicated result widgets with typed mapping).
5. Complete Phase 6 polish and quality/performance evidence.

### Parallel Team Strategy

1. Team completes Setup + Foundational together.
2. After foundational completion:
   - Developer A: US1 query + retrieval pipeline
   - Developer B: US2 segmented filtering behavior
   - Developer C: US3 dedicated widget rendering
3. Merge each story after independent test criteria pass.
