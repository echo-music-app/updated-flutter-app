# Tasks: Spotify Player PoC Screen

**Input**: Design documents from `/specs/004-spotify-player-poc/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, contracts/ ✅, quickstart.md ✅

**Tests**: Included — constitution (Principle II) mandates test-first (Red-Green-Refactor). Write and confirm each test FAILS before implementing.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1–US6)
- Exact file paths are included in every task description

## Path Conventions

```text
backend/src/backend/       # FastAPI source (Python 3.13)
backend/tests/             # pytest tests
mobile/lib/features/       # Flutter feature modules
mobile/lib/core/           # Shared Flutter services
mobile/lib/shared/         # Routing, design tokens
mobile/lib/l10n/           # ARB translation files
mobile/test/widget/        # Flutter widget tests
```

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Add all new dependencies and environment scaffolding before any story work begins.

- [X] T001 Add backend dependencies: move `httpx` to prod deps and add `cryptography` in `backend/pyproject.toml`; run `uv sync` to update `backend/uv.lock`
- [X] T002 [P] Add Flutter dependencies `spotify_sdk ^3.0.2`, `flutter_inappwebview ^6.1.0`, `dio ^5.x`, `cached_network_image ^3.4.0`, `app_links ^7.0.0`, `url_launcher ^6.x` to `mobile/pubspec.yaml`; run `flutter pub get` to update `mobile/pubspec.lock`
- [X] T003 [P] Add backend env vars `SPOTIFY_CLIENT_ID`, `SPOTIFY_CLIENT_SECRET`, `SPOTIFY_REDIRECT_URI`, `SPOTIFY_TOKEN_ENCRYPTION_KEY` to `backend/src/backend/core/config.py` (Pydantic `Settings`; token key as `SecretStr`); update `backend/.env.example`
- [X] T004 [P] Add new ARB strings to `mobile/lib/l10n/app_en.arb`: `connectWithSpotify`, `openPlayer`, `openWebViewPlayer`, `loadingTracks`, `errorLoadingTracks`, `retryButton`, `premiumRequired`, `previousTrack`, `nextTrack`, `playButton`, `pauseButton`, `unknownTrack`, `unknownArtist`, `webViewLimitationNotice`, `webViewPlayerLoadError`
- [X] T005 [P] Create directory scaffolding: `mobile/lib/features/player_webview/widgets/`, `mobile/lib/core/spotify/models/`, `backend/src/backend/api/v1/` (if absent), `backend/tests/contract/`, `backend/tests/integration/` (if absent)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before any user story begins — database model, encryption service, Alembic migration, shared Flutter data-layer models, and routing skeleton.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

### Backend: Token Encryption & spotify_credentials Table

- [X] T006 Write unit test for AES-256-GCM encrypt/decrypt round-trip (must FAIL first) in `backend/tests/unit/test_token_encryption.py`
- [X] T007 Implement `TokenEncryptionService` (encrypt/decrypt using `cryptography` + `SPOTIFY_TOKEN_ENCRYPTION_KEY`; versioned key-envelope prefix on ciphertext) in `backend/src/backend/core/encryption.py`
- [X] T008 Write unit test for `SpotifyCredentials` SQLAlchemy model fields and `__tablename__` (must FAIL first) in `backend/tests/unit/test_spotify_credentials_model.py`
- [X] T009 [P] Create `SpotifyCredentials` SQLAlchemy model (`id` UUID PK, `user_id` UUID FK UNIQUE, `access_token` BYTEA, `refresh_token` BYTEA, `token_expiry` TIMESTAMPTZ, `spotify_user_id` VARCHAR UNIQUE, `scope` TEXT, `created_at`, `updated_at`) in `backend/src/backend/models/spotify_credentials.py`
- [X] T010 Generate Alembic migration: run `uv run alembic revision --autogenerate -m "add_spotify_credentials"` from `backend/`; review generated file in `backend/alembic/versions/`; commit
- [X] T011 Run `uv run migrate`; write integration test for DB upsert on re-auth (`ON CONFLICT (spotify_user_id) DO UPDATE`) in `backend/tests/integration/test_spotify_credentials.py`

### Mobile: Shared Data-Layer Models & Routing

- [X] T012 [P] Create `Track` Dart model (fields: `id`, `uri`, `name`, `artistName`, `albumArtUrl`, `durationMs`; `fromJson` factory; assert `durationMs > 0`) in `mobile/lib/core/spotify/models/track.dart`
- [X] T013 [P] Create `Queue` Dart model (`tracks`, `currentIndex`; derived: `currentTrack`, `hasPrevious`, `hasNext`; `skipNext`/`skipPrevious` that guard boundaries; asserts `tracks.length >= 2`) in `mobile/lib/core/spotify/models/queue.dart`
- [X] T014 [P] Create `SpotifyAuthService` stub (read/write `echoAccessToken`/`echoRefreshToken` from `flutter_secure_storage` using constants `echo_access_token`, `echo_refresh_token`) in `mobile/lib/core/spotify/spotify_auth_service.dart`
- [X] T015 [P] Create `SpotifyQueueRepository` with hardcoded list of ≥2 Spotify track URIs (data layer only — URIs only, no display values in UI layer) in `mobile/lib/core/spotify/spotify_queue_repository.dart`
- [X] T016 Register routes `/login`, `/player`, `/player-webview` in `mobile/lib/shared/routing/app_router.dart`; `/player-webview` maps to a placeholder widget; startup checks secure storage and routes to `/login` or stored destination

**Checkpoint**: Foundation ready — user story implementation can now begin.

---

## Phase 3: User Story 2 — Authenticate with Spotify (Priority: P1) 🎯 MVP Blocker

**Goal**: User completes Spotify OAuth PKCE flow via the Echo backend proxy; receives Echo opaque tokens stored in secure storage; is navigated to the player screen. No Spotify credential touches the mobile app.

**Independent Test**: Launch app → Spotify login screen appears → complete OAuth → `POST /v1/auth/spotify/token` succeeds → player screen becomes accessible → access token expiry handled transparently (SC-007, SC-008).

### Tests for User Story 2

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T017 [P] [US2] Contract test for `POST /v1/auth/spotify/token` (200, 400, 401, 422, 503 cases) in `backend/tests/contract/test_spotify_auth.py`
- [X] T018 [P] [US2] Contract test for `POST /v1/auth/spotify/refresh` (200, 401, 503 cases) in `backend/tests/contract/test_spotify_auth.py`
- [X] T019 [P] [US2] Widget test for `SpotifyLoginScreen`: shows two buttons after auth; "Open Player" navigates to `/player`; "Open WebView Player" navigates to `/player-webview` in `mobile/test/widget/login/spotify_login_screen_test.dart`

### Implementation for User Story 2

- [X] T020 [US2] Implement `SpotifyService.exchange_code(code, code_verifier, redirect_uri)` — calls `https://accounts.spotify.com/api/token`; fetches Spotify user ID from `https://api.spotify.com/v1/me`; upserts `SpotifyCredentials` row with encrypted tokens; returns Echo opaque token pair — in `backend/src/backend/services/spotify_service.py`
- [X] T021 [US2] Implement `SpotifyService.refresh_token(echo_refresh_token)` — proactively refreshes Spotify token if within 60 s of expiry; rotates Echo token pair; handles Spotify 401 (revoked) by deleting row and returning 401 — in `backend/src/backend/services/spotify_service.py`
- [X] T022 [US2] Implement `POST /v1/auth/spotify/token` FastAPI endpoint (request: `code`, `code_verifier`, `redirect_uri`; validates `redirect_uri` against allowlist; response: `access_token`, `refresh_token`, `token_type`, `expires_in`) in `backend/src/backend/api/v1/spotify_auth.py`
- [X] T023 [US2] Implement `POST /v1/auth/spotify/refresh` FastAPI endpoint in `backend/src/backend/api/v1/spotify_auth.py`
- [X] T024 [US2] Register `spotify_auth` router with prefix `/v1/auth` in `backend/src/backend/main.py`; add shared `httpx.AsyncClient` lifespan instance (timeouts: `connect=5 s`, `read=10 s`; separate instances for `accounts.spotify.com` and `api.spotify.com`)
- [X] T025 [US2] Implement mobile `SpotifyAuthService`: PKCE `code_verifier`/`code_challenge` generation; open Spotify `/authorize` URL via `url_launcher`; intercept redirect via `app_links`; extract `code`; call `POST /v1/auth/spotify/token` via `dio`; store Echo tokens in `flutter_secure_storage` — in `mobile/lib/core/spotify/spotify_auth_service.dart`
- [X] T026 [US2] Implement `SpotifyLoginScreen` widget: "Connect with Spotify" triggers auth flow; on success shows two buttons ("Open Player" → `/player`, "Open WebView Player" → `/player-webview`); loading state during OAuth; error state with retry on failure; all strings from ARB — in `mobile/lib/features/login/spotify_login_screen.dart`
- [X] T027 [US2] Serve `/.well-known/assetlinks.json` (Android App Links) and `/.well-known/apple-app-site-association` (iOS Universal Links) as static routes in `backend/src/backend/api/v1/spotify_auth.py` or a dedicated well-known router
- [X] T028 [US2] Configure Android App Links in `mobile/android/app/src/main/AndroidManifest.xml`: `<intent-filter android:autoVerify="true">` for HTTPS redirect URI; set `android:hardwareAccelerated="true"` on `<application>`
- [X] T029 [US2] Configure iOS Universal Links: enable Associated Domains entitlement (`applinks:<your-domain>`) in `mobile/ios/Runner/Runner.entitlements`

**Checkpoint**: Spotify authentication works end-to-end; Echo tokens stored in secure storage; login screen navigates to both player routes.

---

## Phase 4: User Story 1 — View Now Playing Track Info (Priority: P1) 🎯 MVP

**Goal**: Player screen loads and displays current track's album art, name, and artist — all sourced from the Spotify Web API via the Echo backend. No hardcoded values in the UI layer.

**Independent Test**: Open `/player` → album art, track name, and artist displayed correctly → data layer audit confirms zero hardcoded UI track values → loading and error states function (SC-006).

### Tests for User Story 1

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T030 [P] [US1] Contract test for `GET /v1/tracks/{track_id}` (200, 401, 404, 503 cases) in `backend/tests/contract/test_tracks.py`
- [X] T031 [P] [US1] Widget test for `PlayerScreen` loading state: shows `CircularProgressIndicator`; no track data visible in `mobile/test/widget/player_screen_test.dart`
- [X] T032 [P] [US1] Widget test for `PlayerScreen` data state: album art visible; track name and artist rendered from injected `Track` model; no hardcoded string literals in `mobile/test/widget/player_screen_test.dart`
- [X] T033 [P] [US1] Widget test for `PlayerScreen` error state: human-readable message visible; retry button present; no stack traces or raw error codes in `mobile/test/widget/player_screen_test.dart`
- [X] T034 [P] [US1] Widget test for `AlbumArtWidget`: renders `AlbumArtPlaceholder` when `albumArtUrl` is empty or image load fails in `mobile/test/widget/player/album_art_widget_test.dart`

### Implementation for User Story 1

- [X] T035 [US1] Implement `GET /v1/tracks/{track_id}` FastAPI endpoint: authenticate Echo token; retrieve stored Spotify access token; call `https://api.spotify.com/v1/tracks/{id}`; return `{id, uri, name, artist_name, album_art_url, duration_ms}`; surface Spotify 429 → 503 — in `backend/src/backend/api/v1/tracks.py`; register router in `backend/src/backend/main.py`
- [X] T036 [US1] Implement `SpotifyTrackRepository` in mobile: `fetchTrack(trackId)` calls `GET /v1/tracks/{trackId}` via `dio` with Bearer token; deserialises response to `Track` model — in `mobile/lib/core/spotify/spotify_track_repository.dart`
- [X] T037 [US1] Implement `AlbumArtWidget` using `CachedNetworkImage`: `placeholder` callback shows `AlbumArtPlaceholder`; `errorWidget` callback shows `AlbumArtPlaceholder` — in `mobile/lib/features/player/widgets/album_art_widget.dart`
- [X] T038 [US1] Create `TrackPlaybackState` model (`isPlaying`, `positionMs`, `lastPositionTimestamp`, `currentTrack`, `restrictions`) in `mobile/lib/core/player/track_playback_state.dart`
- [X] T039 [US1] Implement `PlayerController` (extends `ChangeNotifier`): on init load queue from `SpotifyQueueRepository`; fetch initial `Track` metadata via `SpotifyTrackRepository`; expose `TrackPlaybackState`; manage loading/error/data state — in `mobile/lib/core/player/player_controller.dart`
- [X] T040 [US1] Implement `PlayerScreen` widget: `ListenableBuilder` on `PlayerController`; loading → `CircularProgressIndicator`; data → `AlbumArtWidget` + track name + artist text (all from `Track` model, no hardcoded UI values); error → human-readable message + retry button; all strings from ARB — in `mobile/lib/features/player/player_screen.dart`

**Checkpoint**: `/player` shows track info from Spotify Web API. Full MVP — can be demoed here.

---

## Phase 5: User Story 3 — Play and Pause via Spotify SDK (Priority: P2)

**Goal**: User taps play/pause on the native SDK screen and the Spotify SDK responds; button icon reflects current playback state; Premium-required error surfaced clearly.

**Independent Test**: Tap play → Spotify SDK begins playback → button icon changes to pause within 100 ms (SC-002). Tap pause → playback stops → icon returns to play. Non-Premium user sees `premiumRequired` message.

### Tests for User Story 3

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T041 [P] [US3] Widget test: `TrackPlaybackState(isPlaying: false)` → play button shown; tap → `PlayerController.play()` called in `mobile/test/widget/player_screen_test.dart`
- [X] T042 [P] [US3] Widget test: `TrackPlaybackState(isPlaying: true)` → pause button shown; tap → `PlayerController.pause()` called in `mobile/test/widget/player_screen_test.dart`
- [X] T043 [P] [US3] Widget test: `PlayerScreen` shows `premiumRequired` ARB message when `PlayerController` emits Premium error state in `mobile/test/widget/player_screen_test.dart`

### Implementation for User Story 3

- [X] T044 [US3] Extend `PlayerController`: connect to `SpotifySdk.connectToSpotifyRemote(clientId, redirectUrl)` on init; subscribe to `SpotifySdk.subscribePlayerState()` stream; update `TrackPlaybackState` on every SDK event; start `Timer.periodic(500ms)` to interpolate seek position between events; detect Premium error and expose as error state — in `mobile/lib/core/player/player_controller.dart`
- [X] T045 [US3] Implement `PlayerController.play()` → `SpotifySdk.resume()` and `PlayerController.pause()` → `SpotifySdk.pause()` in `mobile/lib/core/player/player_controller.dart`
- [X] T046 [US3] Implement `PlaybackControls` widget: play/pause `IconButton` (icon driven by `TrackPlaybackState.isPlaying`; semantic labels `playButton`/`pauseButton` from ARB); prev/next buttons (disabled state driven by `hasPrevious`/`hasNext`; semantic labels `previousTrack`/`nextTrack` from ARB); all taps delegate to `PlayerController` — in `mobile/lib/features/player/widgets/playback_controls.dart`
- [X] T047 [US3] Integrate `PlaybackControls` into `PlayerScreen` data state; wire all `PlayerController` commands in `mobile/lib/features/player/player_screen.dart`

**Checkpoint**: Native SDK play/pause functional; button icon reflects SDK state; Premium error surfaces with ARB message.

---

## Phase 6: User Story 4 — Seek Through the Track (Priority: P3)

**Goal**: User drags the seek bar to jump to any position; elapsed/total times display; Spotify SDK seeks to correct position within 500 ms of release (SC-003); drag while paused keeps position without resuming.

**Independent Test**: Track playing → drag seek bar to 50% → release → SDK seeks to midpoint → elapsed time updates; drag while paused → position updates → play resumes from new position.

### Tests for User Story 4

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T048 [P] [US4] Widget test: `SeekBarWidget` renders elapsed time and total duration formatted as `mm:ss` from `TrackPlaybackState` in `mobile/test/widget/player/seek_bar_widget_test.dart`
- [X] T049 [P] [US4] Widget test: `SeekBarWidget` `onChangeEnd` calls `PlayerController.seekTo(positionMs)` in `mobile/test/widget/player/seek_bar_widget_test.dart`
- [X] T050 [P] [US4] Widget test: during drag `_isDragging` suppresses incoming SDK position updates; thumb stays at dragged position in `mobile/test/widget/player/seek_bar_widget_test.dart`

### Implementation for User Story 4

- [X] T051 [US4] Implement `PlayerController.seekTo(int positionMs)` → `SpotifySdk.seekTo(positionMs)`; set `_isDragging = true`; clear on next SDK event confirming the new position — in `mobile/lib/core/player/player_controller.dart`
- [X] T052 [US4] Implement `SeekBarWidget` using Flutter `Slider`: `onChangeStart` sets `_isDragging = true`; `onChanged` updates local `_dragPosition` only; `onChangeEnd` calls `PlayerController.seekTo()`; elapsed/total times via `_formatMs(int ms)` helper (`mm:ss`); suppress SDK position while `_isDragging` — in `mobile/lib/features/player/widgets/seek_bar_widget.dart`
- [X] T053 [US4] Integrate `SeekBarWidget` into `PlayerScreen` data state in `mobile/lib/features/player/player_screen.dart`

**Checkpoint**: Seek bar fully functional with optimistic drag; elapsed and total times display; reconciles with SDK on drag release.

---

## Phase 7: User Story 5 — Navigate the Queue (Priority: P4)

**Goal**: User taps prev/next to move between tracks; all metadata (album art, name, artist) updates from Spotify Web API within 300 ms (SC-004); buttons disabled at queue boundaries.

**Independent Test**: Tap next → SDK skips → UI fetches and displays new metadata. First track → prev disabled. Last track → next disabled.

### Tests for User Story 5

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T054 [P] [US5] Widget test: next button tap → `PlayerController.skipNext()` called; track info updates to next `Track` in `mobile/test/widget/player_screen_test.dart`
- [X] T055 [P] [US5] Widget test: prev button disabled when `hasPrevious == false`; next button disabled when `hasNext == false` in `mobile/test/widget/player_screen_test.dart`
- [X] T056 [P] [US5] Widget test: on track change `PlayerScreen` re-fetches metadata and re-renders album art, track name, artist in `mobile/test/widget/player_screen_test.dart`

### Implementation for User Story 5

- [X] T057 [US5] Implement `PlayerController.skipNext()` → `SpotifySdk.skipNext()`; on SDK track change event: advance `Queue.currentIndex`, fetch new `Track` metadata via `SpotifyTrackRepository`, update `TrackPlaybackState.currentTrack` — in `mobile/lib/core/player/player_controller.dart`
- [X] T058 [US5] Implement `PlayerController.skipPrevious()` → `SpotifySdk.skipPrevious()`; on SDK track change event: decrement `Queue.currentIndex`, fetch new metadata — in `mobile/lib/core/player/player_controller.dart`
- [X] T059 [US5] Expose `PlayerController.hasPrevious` / `PlayerController.hasNext` from `Queue` state; `PlaybackControls` prev/next disabled state already wired in T046 — verify binding is correct in `mobile/lib/features/player/widgets/playback_controls.dart`

**Checkpoint**: Full queue navigation on native SDK screen; boundaries enforced; metadata from Spotify Web API updates on track change.

---

## Phase 8: User Story 6 — Access WebView Player Screen (Priority: P2)

**Goal**: User navigates from login screen to `/player-webview`; Spotify iframe embed renders; full parity controls displayed; persistent limitation banner explains audio unavailability; queue navigation reloads iframe with new track URL.

**Independent Test**: Navigate to `/player-webview` → iframe loads → all controls at parity with native screen → limitation banner persistent → prev/next update iframe URL → back returns to login without affecting `/player` (US6 acceptance scenarios).

### Tests for User Story 6

> **Write these tests FIRST — confirm each FAILS before implementing**

- [X] T060 [P] [US6] Widget test: `PlayerWebViewScreen` loading state shows `CircularProgressIndicator`; no iframe visible in `mobile/test/widget/player_webview_screen_test.dart`
- [X] T061 [P] [US6] Widget test: `PlayerWebViewScreen` data state renders `SpotifyIframeWidget` and `WebViewLimitationBanner` in `mobile/test/widget/player_webview_screen_test.dart`
- [X] T062 [P] [US6] Widget test: `PlayerWebViewScreen` error state shows human-readable error message (`webViewPlayerLoadError` ARB key) and retry button; no stack traces; retry tap → loading state in `mobile/test/widget/player_webview_screen_test.dart`
- [X] T063 [P] [US6] Widget test: prev button disabled on first track; next button disabled on last track; tap next → iframe URL param updates to next track ID in `mobile/test/widget/player_webview_screen_test.dart`
- [X] T064 [P] [US6] Widget test: `WebViewLimitationBanner` renders `webViewLimitationNotice` ARB string; no raw key fallback in `mobile/test/widget/webview_limitation_banner_test.dart`
- [X] T065 [P] [US6] Widget test: `SpotifyIframeWidget` calls `onLoaded` on `onLoadStop`; calls `onError` on `onLoadError` in `mobile/test/widget/spotify_iframe_widget_test.dart`

### Implementation for User Story 6

- [X] T066 [US6] Implement `WebViewLimitationBanner` stateless widget: renders `AppLocalizations.of(context).webViewLimitationNotice`; always visible in data state; no dismiss action — in `mobile/lib/features/player_webview/widgets/webview_limitation_banner.dart`
- [X] T067 [US6] Implement `SpotifyIframeWidget` stateful widget with `AutomaticKeepAliveClientMixin`: constructs embed URL `https://open.spotify.com/embed/track/<trackId>`; loads in `InAppWebView` with `InAppWebViewSettings(javaScriptEnabled: true)`; `onLoadStop` fires `onLoaded` callback; `onLoadError` fires `onError` callback; track navigation calls `InAppWebViewController.loadUrl()` — in `mobile/lib/features/player_webview/widgets/spotify_iframe_widget.dart`
- [X] T068 [US6] Implement `PlayerWebViewScreen` stateful widget: state machine (`loading`/`error`/`data`); on open: fetch queue from `SpotifyQueueRepository`, fetch initial `Track` metadata via `SpotifyTrackRepository` → set iframe track ID → await `onLoaded` → `data` state; `onError` → `error` state; retry → `loading`; prev/next taps update `Queue.currentIndex` and pass new `trackId` to `SpotifyIframeWidget`; buttons disabled at boundaries; `WebViewLimitationBanner` always shown in data state; all strings from ARB — in `mobile/lib/features/player_webview/player_webview_screen.dart`
- [X] T069 [US6] Wire `PlayerWebViewScreen` with real dependencies in `mobile/lib/shared/routing/app_router.dart`: replace placeholder widget with `PlayerWebViewScreen(queueRepository: ..., trackRepository: ..., authService: ...)`

**Checkpoint**: `/player-webview` functional; iframe renders Spotify embed; limitation banner always visible; queue navigation updates iframe URL; all three states (loading/error/data) work.

---

## Phase 9: Polish & Cross-Cutting Concerns

**Purpose**: Constitution compliance gates, accessibility, OpenAPI schema, and final validation.

- [X] T070 [P] Add `Semantics` labels to all interactive elements in `PlayerScreen` and `PlayerWebViewScreen` (play/pause, seek bar, prev/next, retry, album art) in `mobile/lib/features/player/` and `mobile/lib/features/player_webview/`
- [X] T071 [P] Verify all new widgets use design tokens (no hardcoded hex or pixel values); confirm light/dark mode renders correctly using existing token package in `mobile/lib/features/player/` and `mobile/lib/features/player_webview/`
- [X] T072 [P] Export and commit OpenAPI schema: `uv run python -c "..."` → `shared/openapi.json`; confirm `/v1/auth/spotify/token`, `/v1/auth/spotify/refresh`, `/v1/tracks/{id}` appear with correct schemas
- [X] T073 [P] Run `flutter analyze` and `dart format --set-exit-if-changed mobile/lib/`; fix all warnings/errors in all modified files in `mobile/lib/`
- [X] T074 [P] Run `uv run lint` and `uv run format` on all new/modified files in `backend/src/backend/`; confirm zero ruff/black/isort errors
- [X] T075 Run full backend test suite `uv run test` from `backend/`; confirm coverage ≥80% (constitution gate); add unit tests to close any coverage gaps
- [X] T076 [P] Run full Flutter widget test suite `flutter test mobile/test/widget/`; confirm all tests pass; no skipped tests without `// TODO:` + linked issue
- [X] T077 Validate quickstart test checklist: step through each scenario in `specs/004-spotify-player-poc/quickstart.md`; document actual vs. target results for SC-002/SC-003/SC-004 on the WebView screen (expected: not met for audio-dependent criteria — document per FR-028)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2)**: Depends on Phase 1 — BLOCKS all user stories.
- **US2 Auth (Phase 3, P1)**: Depends on Phase 2 — BLOCKS all other stories (auth gates everything).
- **US1 Track Info (Phase 4, P1)**: Depends on Phase 3 (needs `SpotifyAuthService` for `GET /v1/tracks`).
- **US3 Play/Pause (Phase 5, P2)**: Depends on Phase 4 (`PlayerController` must exist with SDK connection).
- **US6 WebView (Phase 8, P2)**: Depends on Phase 3 + Phase 4 (needs `Track` model, `SpotifyTrackRepository`, `SpotifyAuthService`); can run in parallel with Phase 5–7.
- **US4 Seek (Phase 6, P3)**: Depends on Phase 5 (`PlayerController` needs SDK subscription from T044).
- **US5 Queue Nav (Phase 7, P4)**: Depends on Phase 5 (`PlayerController` skip methods in T044/T045).
- **Polish (Phase 9)**: Depends on all user story phases.

### Dependency Graph

```
Phase 1 (Setup)
  └─ Phase 2 (Foundation)
       └─ Phase 3 (US2: Auth) ← BLOCKS everything below
            ├─ Phase 4 (US1: Track Info) ← MVP deliverable
            │    └─ Phase 5 (US3: Play/Pause)
            │         ├─ Phase 6 (US4: Seek)
            │         └─ Phase 7 (US5: Queue Nav)
            └─ Phase 8 (US6: WebView) ← parallel with Phase 5–7
  └─ Phase 9 (Polish) ← after all stories done
```

### Within Each User Story

- Tests MUST be written and confirmed FAIL before implementation begins (constitution Principle II)
- Models → Services → Endpoints/Widgets (within each phase)
- Core implementation before integration into parent screens

### Parallel Opportunities

- Phase 1: T001–T005 all parallel
- Phase 2: T006–T011 (backend stream) parallel with T012–T015 (mobile stream); T016 after T012–T015
- Phase 3: T017–T019 parallel; T020–T021 parallel before T022–T023; T028–T029 parallel
- Phase 4: T030–T034 (tests) all parallel; T036–T039 partially parallel
- Phase 8: T060–T065 (tests) all parallel; T066–T067 parallel before T068
- Phase 9: T070–T074, T076 all parallel

---

## Parallel Example: Phase 2 (Foundational)

```text
Stream A — Backend (T006 → T007 → T008 → T009 → T010 → T011)
Stream B — Mobile  (T012 + T013 + T014 + T015 in parallel → T016)
```

## Parallel Example: Phase 8 (US6 WebView)

```text
All tests first (parallel): T060 + T061 + T062 + T063 + T064 + T065
Then implementation:
  T066 + T067 (parallel — different files)
    └─ T068 (depends on T066, T067)
         └─ T069 (routing wire-up)
```

---

## Implementation Strategy

### MVP First (US2 + US1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL — blocks all stories)
3. Complete Phase 3: US2 Authentication
4. Complete Phase 4: US1 Track Info
5. **STOP and VALIDATE**: `/player` displays Spotify track info post-login
6. Demo: user logs in → sees album art, track name, artist from Spotify Web API

### Incremental Delivery

| Milestone | Phases | Deliverable |
|-----------|--------|-------------|
| MVP | 1–4 | Auth + track info on `/player` |
| Play/Pause | + 5 | SDK playback control |
| Full Native Player | + 6–7 | Seek bar + queue navigation |
| WebView PoC | + 8 | `/player-webview` iframe screen |
| Release-ready | + 9 | Polish, a11y, OpenAPI, CI gates |

### Parallel Team Strategy (2 developers)

After Phase 3 (Auth) + Phase 4 (Track Info) complete:
- **Dev A**: Phase 5 → Phase 6 → Phase 7 (native SDK play/pause → seek → queue)
- **Dev B**: Phase 8 (WebView screen) in parallel

---

## Notes

- `[P]` = different files, no dependency on incomplete sibling tasks in the same phase
- `[US#]` label maps each task to its user story for traceability
- Constitution Principle II: every test MUST fail before the corresponding implementation is written
- Constitution Principle VII: all user-facing strings MUST be in `app_en.arb` — never hardcoded in widgets
- `spotify_sdk` requires Spotify Premium and the Spotify app installed on device (Android); surface `premiumRequired` ARB string on SDK error (FR-017)
- WebView audio will not function (Widevine EME unavailable) — documented PoC constraint; SC-002/SC-003 results for WebView screen MUST be documented per FR-028
- Commit after each task or logical group; include task ID (e.g., `T014`) in commit message (constitution commit discipline)
- Stop at any checkpoint to validate the user story independently before proceeding to the next priority