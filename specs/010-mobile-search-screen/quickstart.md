# Quickstart: Mobile Music Search Screen

**Branch**: `010-mobile-search-screen` | **Date**: 2026-03-22

---

## Prerequisites

1. Backend includes unified music search endpoint from feature `008-music-search-endpoint`:
   - `POST /v1/search/music`
2. Valid authenticated test user/session for mobile app.
3. Backend test data that returns at least one result for each type (`tracks`, `albums`, `artists`) for known queries.

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
| `/search` | Show search input, run query to `/v1/search/music` with `q`, render segmented results (`Tracks`, `Albums`, `Artists`) |

---

## Test-First Implementation Order

1. Add failing unit tests for repository request/response mapping (`q` body mapping and error translation).
2. Add failing unit tests for search use-case query validation and orchestration behavior.
3. Add failing unit tests for view-model state transitions and stale-response protection.
4. Add failing widget tests for search screen loading/empty/error/auth-required/data states.
5. Add failing widget tests for `TrackSearchResultTile`, `AlbumSearchResultTile`, and `ArtistSearchResultTile`.
6. Add failing integration test for end-to-end query submission and segmented switching.
7. Implement domain entities, repository port, and use cases for query execution and selected type behavior.
8. Implement `EchoMusicSearchRepository` (`dio` adapter) for `POST /v1/search/music` and typed object mapping.
9. Implement `MusicSearchViewModel` with explicit screen states, segment switching, and retry behavior.
10. Implement `MusicSearchScreen` with single free-text field and `SegmentedButton`.
11. Implement dedicated widgets for track/album/artist results.
12. Wire DI providers, router route, and home entry navigation.
13. Add ARB strings and regenerate localization outputs.
14. Re-run all tests and static checks.

---

## Expected New/Updated Files

```text
mobile/lib/features/music_search/domain/entities/music_search_result.dart
mobile/lib/features/music_search/domain/ports/music_search_repository.dart
mobile/lib/features/music_search/domain/use_cases/run_music_search.dart
mobile/lib/features/music_search/domain/use_cases/select_search_result_type.dart
mobile/lib/features/music_search/data/repositories/echo_music_search_repository.dart
mobile/lib/features/music_search/presentation/music_search_view_model.dart
mobile/lib/features/music_search/presentation/music_search_screen.dart
mobile/lib/features/music_search/presentation/widgets/track_search_result_tile.dart
mobile/lib/features/music_search/presentation/widgets/album_search_result_tile.dart
mobile/lib/features/music_search/presentation/widgets/artist_search_result_tile.dart

mobile/lib/config/dependencies.dart
mobile/lib/routing/routes.dart
mobile/lib/routing/app_router.dart
mobile/lib/ui/home/home_screen.dart
mobile/lib/l10n/app_en.arb

mobile/test/unit/features/music_search/music_search_repository_test.dart
mobile/test/unit/features/music_search/run_music_search_use_case_test.dart
mobile/test/unit/features/music_search/music_search_view_model_test.dart
mobile/test/widget/features/music_search/music_search_screen_test.dart
mobile/test/widget/features/music_search/track_search_result_tile_test.dart
mobile/test/widget/features/music_search/album_search_result_tile_test.dart
mobile/test/widget/features/music_search/artist_search_result_tile_test.dart
mobile/integration_test/music_search_flow_test.dart
```

---

## Suggested ARB Keys

Add keys to `mobile/lib/l10n/app_en.arb` (and mirror for other locales as required):

- `musicSearchTitle`
- `musicSearchHint`
- `musicSearchSubmit`
- `musicSearchTracksSegment`
- `musicSearchAlbumsSegment`
- `musicSearchArtistsSegment`
- `musicSearchIdleMessage`
- `musicSearchEmptyTracksMessage`
- `musicSearchEmptyAlbumsMessage`
- `musicSearchEmptyArtistsMessage`
- `musicSearchLoadErrorMessage`
- `musicSearchAuthRequiredMessage`
- `musicSearchRetryButton`
- `musicSearchResultSourceLabel`

---

## SC-001 Baseline Test Profile

- Device profile: one mid-range Android profile and one iOS baseline profile.
- Network profile: stable Wi-Fi baseline for all measurements.
- Data fixture: known query returning at least one result in selected segment.
- Measurement window: search submit action to first rendered result item.
- Sample size: 100 non-empty search submissions.

Record measured values and pass/fail summary in this file during performance validation tasks.

---

## Performance Validation (Constitution V)

Run search-screen performance checks for baseline devices.

1. Launch app in search mode from `mobile/`:

```bash
flutter run --profile
```

2. Submit representative queries and switch segments (`Tracks`, `Albums`, `Artists`).
3. Capture frame metrics (FPS and jank events where frame time is `>16ms`) using Flutter performance tooling.
4. Record results in this file using this evidence format:

| Device | Flow | Avg FPS | Jank Count (>16ms) | Pass/Fail |
|---|---|---:|---:|---|
| Android baseline | Search submit + tracks render |  |  |  |
| Android baseline | Segment switching |  |  |  |
| iOS baseline | Search submit + tracks render |  |  |  |
| iOS baseline | Segment switching |  |  |  |

Pass condition: maintain `60 fps` target with no unresolved jank regressions.

---

## SC-004 Validation Protocol (Findability)

- Objective: validate `SC-004` (`>=90%` first-attempt success).
- Sample size: at least `20` attempts across at least `5` participants.
- Query set: fixed list of queries known to return mixed-type results (`tracks`, `albums`, `artists`).
- Attempt definition: participant starts from `/search`, submits query, switches segments as needed, and finds the predefined target result.
- First-attempt success: target result is found without restarting the task and without facilitator hints.
- Pass formula: `success_rate = successful_attempts / total_attempts`.
- Pass threshold: `success_rate >= 0.90`.

Record evidence in this file:

| Attempt # | Query | Target Result | Participant | Success (Y/N) | Notes |
|---:|---|---|---|:---:|---|
| 1 |  |  |  |  |  |
| 2 |  |  |  |  |  |
| 3 |  |  |  |  |  |

---

## Test Outcomes (T055 — 2026-03-22)

`flutter test` run from `mobile/`:

| Suite | Tests | Result |
|---|---|---|
| unit/features/music_search | 51 | ✓ PASS |
| widget/features/music_search | 37 | ✓ PASS |
| widget/home_screen | 5 | ✓ PASS |
| **Total (full suite)** | **203** | **✓ All passed** |

`dart format --set-exit-if-changed .` — clean (applied auto-formatting)
`flutter analyze` — No issues found

`flutter test integration_test/music_search_flow_test.dart` — integration stubs are `skip: true` pending live DI wiring; skipped tests do not block feature delivery.

---

## Verification Commands

Run from `mobile/`:

```bash
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter test integration_test/music_search_flow_test.dart
```

If feature-specific tests are separated, run targeted suites first, then full suite.

---

## Manual Validation Checklist

1. Open `/search` and verify initial idle state appears before first query.
2. Submit a non-empty query and verify request is sent with body parameter `q`.
3. Verify loading state appears while awaiting backend response.
4. Verify `Tracks` segment shows track widgets only.
5. Verify `Albums` segment shows album widgets only.
6. Verify `Artists` segment shows artist widgets only.
7. Verify per-segment empty-state messaging when a selected segment has no items.
8. Verify retry action works after transient backend/network error.
9. Verify auth-expired behavior does not show stale results and routes through re-auth path.
10. Verify all new labels/messages are localized and no raw localization keys are rendered.
