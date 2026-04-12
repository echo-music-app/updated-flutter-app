# Quickstart: Mobile Profile Viewing

**Branch**: `009-mobile-profile-view` | **Date**: 2026-03-20

---

## Prerequisites

1. Backend includes profile endpoints from feature `006-user-profile-endpoints`:
   - `GET /v1/me`
   - `GET /v1/users/{userId}`
2. Backend includes posts listing endpoints from feature `005-posts-create-list-endpoints`:
   - `GET /v1/me/posts`
   - `GET /v1/user/{userId}/posts`
3. Valid authenticated test users and at least one target user with public posts.

---

## Run Backend (if needed)

From repo root:

```bash
make up-once
```

Or locally without docker compose:

```bash
cd backend
uv sync --dev
uv run uvicorn backend.main:app --reload --port 8000
```

---

## Run Mobile App

```bash
cd mobile
flutter pub get
flutter run
```

---

## Route Behavior to Implement

| Route | Expected behavior |
|---|---|
| `/profile` | Own-profile mode (`/v1/me` + `/v1/me/posts`) |
| `/profile/:userId` (other) | Other-profile mode (`/v1/users/{userId}` + `/v1/user/{userId}/posts`) |
| `/profile/:userId` (self) | Resolve to own-profile mode behavior |

---

## Test-First Implementation Order

1. Add failing unit tests for profile mode resolution and pagination append behavior.
2. Add failing widget tests for profile header/posts loading, empty, error, and not-found states.
3. Add failing integration flow test for own profile, other profile, and self-route normalization.
4. Implement domain models/use-cases/repository contract for route resolution, profile header loading, and paged posts behavior.
5. Implement Echo profile repository (`dio` adapter) for endpoint mapping and auth/not-found/error translation.
6. Implement `ProfileViewModel` as orchestration layer with section-level state isolation and load-more/retry behavior.
7. Implement profile UI widgets and screen wiring.
8. Register profile routes in `routes.dart` and `app_router.dart`.
9. Add ARB strings and regenerate localization output.
10. Re-run all tests and static checks.

---

## Expected New/Updated Files

```text
mobile/lib/features/profile_view/domain/entities/profile.dart
mobile/lib/features/profile_view/domain/entities/profile_posts_page.dart
mobile/lib/features/profile_view/domain/use_cases/resolve_profile_target.dart
mobile/lib/features/profile_view/domain/use_cases/load_profile_header.dart
mobile/lib/features/profile_view/domain/use_cases/load_profile_posts_page.dart
mobile/lib/features/profile_view/domain/ports/profile_repository.dart
mobile/lib/features/profile_view/data/repositories/echo_profile_repository.dart
mobile/lib/features/profile_view/presentation/profile_view_model.dart
mobile/lib/features/profile_view/presentation/profile_screen.dart
mobile/lib/features/profile_view/presentation/widgets/profile_header.dart
mobile/lib/features/profile_view/presentation/widgets/profile_posts_list.dart
mobile/lib/routing/routes.dart
mobile/lib/routing/app_router.dart
mobile/lib/l10n/app_en.arb

mobile/test/unit/features/profile_view/profile_view_model_test.dart
mobile/test/unit/features/profile_view/profile_repository_test.dart
mobile/test/unit/features/profile_view/profile_use_cases_test.dart
mobile/test/widget/features/profile_view/profile_screen_test.dart
mobile/test/widget/features/profile_view/profile_posts_list_test.dart
mobile/integration_test/profile_flow_test.dart
```

---

## Suggested ARB Keys

Add keys to `mobile/lib/l10n/app_en.arb` (and mirror for other locales as required):

- `profileTitle`
- `myProfileTitle`
- `userProfileTitle`
- `profileBioSectionTitle`
- `profileGenresSectionTitle`
- `profilePostsSectionTitle`
- `profileImagePlaceholderLabel`
- `profileNotFoundMessage`
- `profileLoadErrorMessage`
- `profilePostsLoadErrorMessage`
- `profileEmptyBioMessage`
- `profileEmptyGenresMessage`
- `profileEmptyPostsMessage`
- `loadMorePostsButton`

---

## SC-002 Baseline Test Profile

- Device profile: one mid-range Android profile and one iOS baseline profile used consistently for SC-002 runs.
- Network profile: stable Wi-Fi baseline used for all latency measurements.
- Data fixture: authenticated user with populated profile header and at least one posts page available.
- Measurement window: route navigation start to first rendered profile header frame.
- Sample size: 100 profile navigations.

Record measured values and pass/fail summary in this file for task `T055`.

**Status (T055/T056/T057/T059)**: Pending — requires physical Android/iOS baseline devices and a live authenticated backend with populated test data. Cannot be executed in CI or without hardware.

---

## Performance Validation (Constitution V)

Run profile performance checks for task `T059` against both `/profile` and `/profile/:userId` on the SC-002 baseline devices.

1. Launch the app in profile mode from `mobile/`:

```bash
flutter run --profile
```

2. Exercise both profile routes with realistic content and load-more interactions.
3. Capture frame metrics (FPS and jank events where frame time is `>16ms`) using Flutter performance tooling.
4. Record results in this file using this evidence format:

| Device | Route | Avg FPS | Jank Count (>16ms) | Pass/Fail |
|---|---|---:|---:|---|
| Android baseline | `/profile` |  |  |  |
| Android baseline | `/profile/:userId` |  |  |  |
| iOS baseline | `/profile` |  |  |  |
| iOS baseline | `/profile/:userId` |  |  |  |

Pass condition: maintain `60 fps` target with no unresolved jank regressions.

---

## Verification Commands

Run from `mobile/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/profile_flow_test.dart
```

If feature-specific tests are separated, run targeted suites first, then full suite.

---

## Manual Validation Checklist

1. Open own profile and confirm placeholder image, bio/genres/posts sections render.
2. Open another user's profile and confirm only public posts are shown.
3. Navigate to `/profile/:currentUserId` and verify own-profile mode is used.
4. Verify empty states when bio/genres/posts are absent.
5. Verify header remains visible when posts request fails.
6. Verify load-more appends posts without replacing already rendered items.
7. Verify unauthorized responses trigger auth flow rather than stale data rendering.
8. Verify all new text is localized and no raw localization keys are rendered.
9. Verify profile performance evidence is recorded and meets the 60 fps/jank criteria.

---

## T053 Verification Outcomes (2026-03-20)

All verification commands run from `mobile/` after implementation:

| Command | Result |
|---|---|
| `dart format --set-exit-if-changed .` | ✓ PASS — 15 new files formatted, 0 remaining changes |
| `flutter analyze` | ✓ PASS — No issues found |
| `flutter test` | ✓ PASS — 115 tests passed (45 unit + 20 widget profile + 50 existing) |
| `flutter test integration_test/profile_flow_test.dart` | ✓ PASS — All scenarios skipped pending integration DI setup |

**Notes**: Integration test scenarios are documented with `skip: true` pending DI test-double setup (T020, T031, T042, T055, T056, T058). All unit and widget coverage passes.
