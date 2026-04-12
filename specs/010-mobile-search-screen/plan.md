# Implementation Plan: Mobile Music Search Screen

**Branch**: `010-mobile-search-screen` | **Date**: 2026-03-22 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/010-mobile-search-screen/spec.md`

## Summary

Implement a new mobile search screen that submits one free-text query to existing backend endpoint `POST /v1/search/music` using request parameter `q`, maps grouped `tracks[]`, `albums[]`, and `artists[]` responses into typed domain objects, and renders each type via dedicated widgets. A `SegmentedButton` controls active result type without re-querying, while view-model state handles loading/empty/error/authRequired outcomes and clears stale data across searches.

## Technical Context

**Language/Version**: Dart SDK `^3.11.0` (Flutter stable)  
**Primary Dependencies**: Flutter SDK (`Material` + `SegmentedButton`), `provider`, `go_router`, `dio`, `flutter_localizations`, `intl`, generated `AppLocalizations`  
**Storage**: No new persistence; existing secure token storage via `AuthRepository` only  
**Testing**: `flutter_test` (unit + widget), `integration_test` (critical search flow), strict test-first red/green/refactor  
**Target Platform**: Android (API 26+) and iOS (iOS 14+)  
**Project Type**: Mobile app feature slice consuming an existing backend API  
**Performance Goals**: Preserve 60 fps interactions and satisfy SC-001 (>=95% of searches render first visible results in <=2.0s under baseline conditions)  
**Constraints**: Must consume existing `/v1/search/music` contract (send `q`), provide exactly three result-type segments (`tracks`, `albums`, `artists`), map backend results to app objects before rendering, use dedicated widgets per type, externalize all UI text via ARB, add semantics labels to interactive controls, and keep business rules in domain/use-case layer  
**Scale/Scope**: One new search route/screen, one feature-level domain/data/presentation slice, DI/routing/home-entry integration updates, and targeted unit/widget/integration coverage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|---|---|---|
| I. Code Quality & Standards | ✅ PASS | Plan includes `dart format --set-exit-if-changed .` and `flutter analyze`; feature files are scoped by single responsibility |
| II. Test-First Discipline | ✅ PASS | Unit, widget, and integration tests are planned before implementation for repository mapping, use cases, view-model state, and screen flows |
| III. API Contract Integrity | ✅ PASS | Existing versioned endpoint `/v1/search/music` is consumed without API mutation; contract artifact documents exact request/response use |
| IV. User Experience Consistency | ✅ PASS | Explicit loading, empty, error, and authRequired states are defined for the search screen and each selected result type |
| V. Performance Standards | ✅ PASS | Single-request fetch + client-side segment switching avoids repeated network calls and supports responsive 60 fps UI behavior |
| VI. Security by Design | ✅ PASS | Authenticated API usage is preserved, tokens remain opaque in client, and 401 handling routes through existing session-clearing auth flow |
| VII. Localisation & Internationalisation | ✅ PASS | New user-facing strings and segmented labels are ARB-backed; no hardcoded UI copy |
| VIII. Clean Architecture | ✅ PASS | Feature structure uses `domain`/`data`/`presentation` layers with repository port + use-case entry and inward dependency flow |

*Post-design re-check*: All gates remain satisfied after producing `research.md`, `data-model.md`, `contracts/mobile-music-search.md`, and `quickstart.md`.

## Project Structure

### Documentation (this feature)

```text
specs/010-mobile-search-screen/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── mobile-music-search.md
└── tasks.md                 # generated later by /speckit.tasks
```

### Source Code (repository root)

```text
mobile/lib/features/music_search/
├── domain/
│   ├── entities/
│   │   └── music_search_result.dart                # NEW: typed search result models + grouped response model
│   ├── ports/
│   │   └── music_search_repository.dart            # NEW: API consumption contract + typed exceptions
│   └── use_cases/
│       ├── run_music_search.dart                   # NEW: query validation + repository orchestration
│       └── select_search_result_type.dart          # NEW: segmented selection rule for active result type
├── data/
│   └── repositories/
│       └── echo_music_search_repository.dart       # NEW: POST /v1/search/music adapter + DTO mapping
└── presentation/
    ├── music_search_screen.dart                    # NEW: free-text input + segmented control + state rendering
    ├── music_search_view_model.dart                # NEW: query execution + per-type projection + state transitions
    └── widgets/
        ├── track_search_result_tile.dart           # NEW: track-specific result widget
        ├── album_search_result_tile.dart           # NEW: album-specific result widget
        └── artist_search_result_tile.dart          # NEW: artist-specific result widget

mobile/lib/
├── config/
│   └── dependencies.dart                           # UPDATED: music search repository provider wiring
├── routing/
│   ├── routes.dart                                # UPDATED: `Routes.search`
│   └── app_router.dart                            # UPDATED: search route wiring + view-model creation
├── ui/home/
│   └── home_screen.dart                           # UPDATED: navigation entry to search screen
└── l10n/
    └── app_en.arb                                 # UPDATED: search labels/messages/semantics strings

mobile/test/
├── unit/
│   └── features/music_search/
│       ├── music_search_repository_test.dart      # NEW: endpoint mapping and error translation
│       ├── run_music_search_use_case_test.dart    # NEW: query validation + orchestration behavior
│       └── music_search_view_model_test.dart      # NEW: loading/data/empty/error/authRequired + segment switching
└── widget/
    └── features/music_search/
        ├── music_search_screen_test.dart          # NEW: input/search flow + segmented states
        ├── track_search_result_tile_test.dart     # NEW: track widget contract
        ├── album_search_result_tile_test.dart     # NEW: album widget contract
        └── artist_search_result_tile_test.dart    # NEW: artist widget contract

mobile/integration_test/
└── music_search_flow_test.dart                    # NEW: end-to-end search + result-type switching + auth-expired handling
```

**Structure Decision**: Mobile-only feature extension under constitution-compliant per-feature layout `mobile/lib/features/music_search/{domain,data,presentation}` with routing/DI/l10n integration in existing shared app locations. No backend source changes are required because the endpoint already exists.

## Phase 0: Research

`research.md` captures decisions for search trigger behavior, `/v1/search/music` request/response mapping, segmented filtering strategy, typed result object mapping, error/auth handling, localization/accessibility requirements, and test-first strategy.

## Phase 1: Design & Contracts

- `data-model.md` defines query/result entities, grouped result model, view-state transitions, and selected-type projection rules.
- `contracts/mobile-music-search.md` defines backend consumption and mobile route/UI behavior contracts.
- `quickstart.md` defines test-first implementation sequence, verification commands, and manual validation checklist.

## Complexity Tracking

> No constitution violations requiring exception tracking.
