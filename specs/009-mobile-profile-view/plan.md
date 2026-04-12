# Implementation Plan: Mobile Profile Viewing

**Branch**: `009-mobile-profile-view` | **Date**: 2026-03-20 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/009-mobile-profile-view/spec.md`

## Summary

Implement mobile profile viewing for both own and other-user routes by consuming existing `/v1/me`, `/v1/users/{userId}`, `/v1/me/posts`, and `/v1/user/{userId}/posts` endpoints. Use-case-driven profile mode resolution, header loading, and paginated post loading preserve Clean Architecture boundaries while the UI provides explicit loading/empty/error/not-found handling, auth-expiry re-auth prompts, and deterministic profile mode indicators.

## Technical Context

**Language/Version**: Dart SDK `^3.11.0` (Flutter stable)  
**Primary Dependencies**: Flutter SDK, `go_router`, `provider`, `dio`, `flutter_secure_storage`, `flutter_localizations`, `intl`, generated `AppLocalizations`  
**Storage**: No new persistence; existing secure token storage only  
**Testing**: `flutter_test` (unit + widget), `integration_test` (critical profile flows), test-first red/green/refactor  
**Target Platform**: Android (API 26+) and iOS (iOS 14+)  
**Project Type**: Mobile app feature slice consuming existing backend APIs  
**Performance Goals**: Preserve 60 fps interactions and meet SC-002 benchmark (>=95/100 profile navigations render header in <=2.0s)  
**Constraints**: Must consume existing `/v1` profile/posts endpoints; enforce public-only posts in other-profile mode; use cursor pagination; render placeholder image only (no upload/editing); externalize strings via ARB; support light/dark mode and semantics labels; clear stale profile content and prompt re-auth on auth/session-expired responses; keep business rules in `domain/use_cases`  
**Scale/Scope**: One mobile feature flow with route integration, domain use cases/entities/ports, repository adapter, profile presentation layer, and dedicated unit/widget/integration coverage

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|---|---|---|
| I. Code Quality & Standards | ✅ PASS | Plan includes `dart format` + `flutter analyze` quality gates and keeps responsibilities bounded by layer |
| II. Test-First Discipline | ✅ PASS | Unit/widget/integration tests are required before implementation for use cases, repositories, view-model, and screen behavior |
| III. API Contract Integrity | ✅ PASS | Existing `/v1` contracts are consumed without contract mutation and with explicit auth/not-found/error mappings |
| IV. User Experience Consistency | ✅ PASS | Loading/empty/error/not-found/auth-required behavior and actionable retry are defined with section-level isolation |
| V. Performance Standards | ✅ PASS | Cursor pagination + incremental append preserve responsiveness and support SC-002 measurement |
| VI. Security by Design | ✅ PASS | Authenticated endpoint assumptions preserved; auth-expired handling clears stale data and routes through auth flow |
| VII. Localisation & Internationalisation | ✅ PASS | New copy is ARB-backed and localization verification is included in quality workflow |
| VIII. Clean Architecture | ✅ PASS | Feature structure explicitly includes `domain/use_cases`; presentation delegates business rules to domain |

*Post-design re-check*: All gates remain satisfied after producing `research.md`, `data-model.md`, `contracts/mobile-profile-view.md`, and `quickstart.md`.

## Project Structure

### Documentation (this feature)

```text
specs/009-mobile-profile-view/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── mobile-profile-view.md
└── tasks.md                 # generated later by /speckit.tasks
```

### Source Code (repository root)
```text
mobile/lib/features/profile_view/
├── domain/
│   ├── entities/
│   │   ├── profile.dart                         # NEW: profile header + mode model
│   │   └── profile_posts_page.dart              # NEW: paginated profile posts model
│   ├── use_cases/
│   │   ├── resolve_profile_target.dart          # NEW: self-route normalization and mode resolution
│   │   ├── load_profile_header.dart             # NEW: header retrieval + auth/not-found decisions
│   │   └── load_profile_posts_page.dart         # NEW: paged posts loading + retry policy behavior
│   └── ports/
│       └── profile_repository.dart              # NEW: profile data contract
├── data/
│   └── repositories/
│       └── echo_profile_repository.dart         # NEW: /v1/me, /v1/users/{id}, /v1/me/posts, /v1/user/{id}/posts adapter
└── presentation/
    ├── profile_screen.dart                      # NEW: profile UI states + posts pagination UI
    ├── profile_view_model.dart                  # NEW: orchestration that delegates business rules to domain use cases
    └── widgets/
        ├── profile_header.dart                  # NEW: placeholder image, bio, genres summary
        └── profile_posts_list.dart              # NEW: paginated posts list with load-more/retry

mobile/lib/
├── config/
│   └── dependencies.dart                         # UPDATED: profile repository and use-case wiring
├── routing/
│   ├── routes.dart                              # UPDATED: profile route constants
│   └── app_router.dart                          # UPDATED: profile route wiring + self-id normalization
└── l10n/
    └── app_en.arb                               # UPDATED: profile strings

mobile/test/
├── unit/
│   └── features/profile_view/
│       ├── profile_use_cases_test.dart          # NEW: domain use-case decisions and auth handling
│       ├── profile_view_model_test.dart         # NEW: mode resolution, state transitions, pagination behavior
│       └── profile_repository_test.dart         # NEW: endpoint mapping and error translation
└── widget/
    └── features/profile_view/
        ├── profile_screen_test.dart             # NEW: loading/empty/error/not-found/auth-required states
        └── profile_posts_list_test.dart         # NEW: append/loading/retry semantics

mobile/integration_test/
└── profile_flow_test.dart                       # NEW: own profile, other profile, self-route normalization, auth-expiry handling
```

**Structure Decision**: Mobile-only feature extension under constitution-compliant per-feature layout `mobile/lib/features/profile_view/{domain(use_cases,entities,ports),data,presentation}` while keeping route/l10n integration in existing shared locations and preserving inward dependency flow.

## Phase 0: Research

`research.md` captures decisions for endpoint mapping, self-route normalization, section-level state isolation, cursor pagination strategy, auth/session-expiry handling, localization/accessibility requirements, and test-first strategy.

## Phase 1: Design & Contracts

- `data-model.md` defines route target, profile header/post entities, paged posts model, and screen-level state transitions.
- `contracts/mobile-profile-view.md` defines backend consumption and mobile route/UI behavior contracts.
- `quickstart.md` defines implementation sequence, verification commands, and manual validation checklist.

## Complexity Tracking

> No constitution violations requiring exception tracking.
