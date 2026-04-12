# Implementation Plan: Spotify Player PoC Screen

**Branch**: `004-spotify-player-poc` | **Date**: 2026-03-01 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/004-spotify-player-poc/spec.md`

## Summary

Implement a dual-screen Spotify player PoC in the Echo mobile app:
1. **Native SDK screen** (`/player`) — full playback control via `spotify_sdk` (Spotify App Remote), with album art, seek bar, and queue navigation.
2. **WebView iframe screen** (`/player-webview`) — visual-only Spotify iframe embed via `flutter_inappwebview`; audio is unavailable due to Widevine EME constraints (documented limitation).

Both screens are independently accessible from a dedicated Spotify login screen after PKCE OAuth. The Echo backend proxies all Spotify token exchange and track metadata requests; the Spotify client secret never reaches the mobile app.

## Technical Context

**Language/Version**: Dart (Flutter 3.x stable) + Python 3.13
**Primary Dependencies**: `spotify_sdk ^3.0.2`, `flutter_inappwebview ^6.1.0`, `dio ^5.x`, `cached_network_image ^3.4.0`, `app_links ^7.0.0`, `url_launcher ^6.x`; backend: FastAPI, SQLAlchemy (async), Alembic, `httpx` (move to prod deps), `cryptography`
**Storage**: PostgreSQL 18 — new `spotify_credentials` table (AES-256-GCM encrypted token columns); mobile `flutter_secure_storage` for Echo opaque tokens
**Testing**: `flutter_test` + `integration_test` (widget tests per screen state); `pytest` with 100% unit coverage; contract tests for all backend endpoints
**Target Platform**: Android (API 26+), iOS (iOS 14+); backend on Linux
**Project Type**: Mobile app + API backend (monorepo)
**Performance Goals**: SC-002 play/pause state change ≤100 ms; SC-003 seek confirmed ≤500 ms; SC-004 track info update ≤300 ms; SC-007 OAuth flow ≤5 s; 60 fps UI
**Constraints**: Spotify Premium required for SDK playback; audio unavailable in WebView (Widevine); `spotify_sdk` requires Spotify app installed on device (Android); custom URI schemes unreliable post-April 2025 (use App Links / Universal Links); no Spotify credentials in mobile app

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|-----------|--------|-------|
| I. Code Quality — `black`/`isort`/`ruff`, `dart format`/`flutter analyze`, ≤40 lines/fn | ✅ PASS | All new files must comply; enforced in CI |
| II. Test-First — 100% unit coverage (backend), widget tests every screen state (mobile) | ✅ PASS | Test checklist defined in quickstart.md; no skipped tests without `// TODO:` + issue |
| III. API Contract — OAuth opaque tokens, backend-only token issuance, OpenAPI schema committed | ✅ PASS | Echo backend proxy design (FR-014/FR-018); Spotify secret never in mobile |
| IV. UX Consistency — loading/error/data states, design tokens, ARB strings, semantic labels | ✅ PASS | All three states defined for both screens (FR-021/FR-027); ARB strings in quickstart |
| V. Performance — 60 fps, lazy image loading, p95 API latency ≤200 ms (GET) | ✅ PASS | `CachedNetworkImage`; `httpx` async; Timer-based seek bar interpolation only |
| VI. Security — secrets in env vars only, opaque token rotation, no hardcoded credentials | ✅ PASS | `SPOTIFY_TOKEN_ENCRYPTION_KEY` in env; AES-256-GCM at rest; no Spotify tokens in mobile |
| VII. L10n/i18n — all user-facing strings in ARB, `flutter_localizations` + `intl` | ✅ PASS | Full ARB string set defined in quickstart.md; `WebViewLimitationBanner` uses ARB |

**Post-Phase 1 re-check**: All gates still pass. No violations requiring Complexity Tracking.

## Project Structure

### Documentation (this feature)

```text
specs/004-spotify-player-poc/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── spotify-auth-api.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
# Option 3: Mobile + API

backend/src/backend/
├── api/v1/
│   ├── spotify_auth.py         # POST /v1/auth/spotify/token, POST /v1/auth/spotify/refresh
│   └── tracks.py               # GET /v1/tracks/{track_id}
├── models/
│   └── spotify_credentials.py  # SQLAlchemy model for spotify_credentials table
├── services/
│   └── spotify_service.py      # Spotify Web API calls + token encryption/decryption
└── core/
    └── config.py               # +SPOTIFY_CLIENT_ID/SECRET/REDIRECT_URI/TOKEN_ENCRYPTION_KEY

backend/tests/
├── contract/
│   └── test_spotify_auth.py    # POST /token, POST /refresh, GET /tracks/{id}
├── integration/
│   └── test_spotify_credentials.py  # DB upsert, AES encryption round-trip
└── unit/
    └── test_spotify_service.py # Token encryption, refresh logic

mobile/lib/
├── features/
│   ├── login/
│   │   └── spotify_login_screen.dart        # UPDATED: two player route buttons
│   ├── player/                              # UNCHANGED
│   │   ├── player_screen.dart
│   │   └── widgets/
│   │       ├── album_art_widget.dart
│   │       ├── playback_controls.dart
│   │       └── seek_bar_widget.dart
│   └── player_webview/                      # NEW
│       ├── player_webview_screen.dart        # Stateful; loading/error/data state machine
│       └── widgets/
│           ├── spotify_iframe_widget.dart    # InAppWebView with onLoaded/onError callbacks
│           └── webview_limitation_banner.dart # Stateless; ARB string
├── core/
│   ├── player/                              # UNCHANGED
│   │   ├── player_controller.dart
│   │   └── track_playback_state.dart
│   └── spotify/                             # UNCHANGED
│       ├── spotify_auth_service.dart
│       ├── spotify_track_repository.dart
│       └── spotify_queue_repository.dart
├── shared/
│   └── routing/
│       └── app_router.dart                  # UPDATED: register /player-webview
└── l10n/
    └── app_en.arb                           # UPDATED: new strings (see quickstart.md)

mobile/test/
├── widget/
│   ├── player_webview_screen_test.dart      # loading/data/error states; prev/next
│   ├── spotify_iframe_widget_test.dart      # onLoaded/onError callbacks
│   └── webview_limitation_banner_test.dart  # ARB string renders
└── widget/login/
    └── spotify_login_screen_test.dart       # both button routes
```

**Structure Decision**: Option 3 (Mobile + API). The existing monorepo layout is preserved. New mobile code goes under `mobile/lib/features/player_webview/`. New backend code follows the established `api/v1/`, `models/`, `services/`, `core/` pattern already used for auth and other features.

## Complexity Tracking

> No constitution violations detected. No entries required.