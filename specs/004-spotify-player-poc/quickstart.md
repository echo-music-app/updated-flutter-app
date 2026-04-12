# Quickstart: Spotify Player PoC

**Branch**: `004-spotify-player-poc` | **Date**: 2026-02-28 (updated 2026-03-01)

---

## Prerequisites

### Spotify Developer Portal Setup (one-time)

1. Log in to [developer.spotify.com](https://developer.spotify.com/dashboard) and create an app.
2. Add the redirect URI: `https://<your-domain>/auth/callback` (must be HTTPS for App Links / Universal Links).
3. Note your **Client ID** and **Client Secret**.
4. Register your Android SHA-1 signing fingerprint for the app package `com.example.echo`.

### Android Setup

1. Host `/.well-known/assetlinks.json` on `<your-domain>`. The Echo backend serves this file.
2. In `mobile/android/app/src/main/AndroidManifest.xml`, add an `<intent-filter>` for
   `https://<your-domain>/auth/callback` with `android:autoVerify="true"`.
3. Ensure `android:hardwareAccelerated="true"` is set on the `<application>` element (required by
   `flutter_inappwebview` for WebView rendering performance).

### iOS Setup

1. Host `/.well-known/apple-app-site-association` on `<your-domain>`.
2. Enable Associated Domains in your iOS app entitlements: `applinks:<your-domain>`.

---

## Environment Variables

### Backend (`backend/.env`)

```env
DATABASE_URL=postgresql+asyncpg://...
SECRET_KEY=<random 32-byte hex>
SPOTIFY_CLIENT_ID=<from Spotify Developer Portal>
SPOTIFY_CLIENT_SECRET=<from Spotify Developer Portal>
SPOTIFY_REDIRECT_URI=https://<your-domain>/auth/callback
SPOTIFY_TOKEN_ENCRYPTION_KEY=<random 32-byte hex — DIFFERENT from SECRET_KEY>
```

### Mobile (`mobile/lib/core/config/`)

Injected via `--dart-define` at build time:

- `ECHO_BASE_URL` — the Echo backend base URL (e.g., `https://api.echo.example.com`)
- `SPOTIFY_CLIENT_ID` — needed for the `/authorize` redirect URL construction
- `SPOTIFY_REDIRECT_URI` — must match the backend config

---

## Running the Backend

```bash
cd backend
uv sync --dev
uv run migrate          # apply all migrations including spotify_credentials
uv run dev              # starts on :8000
```

---

## Running the Mobile App

```bash
cd mobile
flutter pub get
flutter run             # connects to backend at ECHO_BASE_URL
```

---

## Navigation Flow

```
App launch
  │
  ├─ No Echo token in secure storage
  │    └─ → /login  (SpotifyLoginScreen)
  │              ├─ "Open Player" button
  │              │    → url_launcher opens system browser → Spotify auth
  │              │    → app_links receives redirect → code extracted
  │              │    → POST /v1/auth/spotify/token
  │              │    → Echo tokens stored in flutter_secure_storage
  │              │    └─ → /player  (PlayerScreen — native SDK)
  │              └─ "Open WebView Player" button
  │                   → same auth flow as above
  │                   └─ → /player-webview  (PlayerWebViewScreen — Spotify iframe)
  │
  └─ Echo token present → stored route preference determines destination
       ├─ → /player         (native SDK screen)
       │       ├─ loading  → fetch queue metadata
       │       ├─ data     → full native player UI (spotify_sdk)
       │       └─ error    → error + retry
       └─ → /player-webview  (WebView iframe screen)
               ├─ loading  → fetch queue metadata + load iframe
               ├─ data     → Spotify iframe + limitation banner + prev/next controls
               └─ error    → error + retry
```

---

## Routes (in `AppRouter`)

| Route | Widget | Notes |
|-------|--------|-------|
| `/login` | `SpotifyLoginScreen` | Shown to unauthenticated users; offers both player routes |
| `/player` | `PlayerScreen(controller: PlayerController())` | Native SDK screen — unchanged |
| `/player-webview` | `PlayerWebViewScreen(queueRepository:..., trackRepository:..., authService:...)` | NEW — WebView iframe screen |

---

## Flutter Packages (add to `pubspec.yaml`)

| Package | Version | Purpose |
|---|---|---|
| `spotify_sdk` | `^3.0.2` | Spotify App Remote SDK — native player screen only |
| `flutter_inappwebview` | `^6.1.0` | WebView for Spotify iframe embed — WebView player screen only |
| `dio` | `^5.x` | HTTP client for Echo backend API calls (both screens share) |
| `cached_network_image` | `^3.4.0` | Album art caching — native screen only |
| `app_links` | `^7.0.0` | Intercept HTTPS redirect URI for OAuth callback |
| `url_launcher` | `^6.x` | Open system browser for Spotify OAuth `/authorize` |

---

## Backend Dependencies (add to `pyproject.toml`)

| Package | Purpose |
|---|---|
| `httpx` | Move from `dev` to `dependencies`; async HTTP client for Spotify API calls |
| `cryptography` | AES-256-GCM encryption for Spotify tokens at rest |

---

## Backend Migration

```bash
cd backend
uv run alembic revision --autogenerate -m "add_spotify_credentials"
uv run migrate
```

---

## File Structure (this feature)

### Mobile — what changes

```
mobile/lib/
├── features/
│   ├── login/
│   │   └── spotify_login_screen.dart        # UPDATED: second button → /player-webview
│   ├── player/                              # UNCHANGED — do not modify
│   │   ├── player_screen.dart
│   │   └── widgets/
│   │       ├── album_art_widget.dart
│   │       ├── playback_controls.dart
│   │       └── seek_bar_widget.dart
│   └── player_webview/                      # NEW
│       ├── player_webview_screen.dart        # Stateful; loading/error/data state machine
│       └── widgets/
│           ├── spotify_iframe_widget.dart    # InAppWebView; fires onLoaded/onError callbacks
│           └── webview_limitation_banner.dart # Stateless; reads ARB string
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
    └── app_en.arb                           # UPDATED: new strings (see below)
```

### Backend — what changes (same as original plan)

```
backend/src/backend/
├── api/v1/
│   ├── spotify_auth.py         # POST /v1/auth/spotify/token, POST /v1/auth/spotify/refresh
│   └── tracks.py               # GET /v1/tracks/{track_id}
├── models/
│   └── spotify_credentials.py
├── services/
│   └── spotify_service.py
└── core/
    └── config.py               # +SPOTIFY_CLIENT_ID/SECRET/REDIRECT_URI/TOKEN_ENCRYPTION_KEY
```

---

## ARB Strings (add to `mobile/lib/l10n/app_en.arb`)

```json
{
  "playerTitle": "Now Playing",
  "connectWithSpotify": "Connect with Spotify",
  "openPlayer": "Open Player",
  "openWebViewPlayer": "Open WebView Player",
  "loadingTracks": "Loading track…",
  "errorLoadingTracks": "Failed to load track. Please try again.",
  "retryButton": "Retry",
  "premiumRequired": "Spotify Premium is required for playback.",
  "previousTrack": "Previous track",
  "nextTrack": "Next track",
  "playButton": "Play",
  "pauseButton": "Pause",
  "unknownTrack": "Unknown Track",
  "unknownArtist": "Unknown Artist",
  "webViewLimitationNotice": "Audio playback is not available in the WebView player. This is a known platform limitation (DRM not supported in Android WebView / iOS WKWebView). Visual controls are shown for demonstration purposes.",
  "webViewPlayerLoadError": "Failed to load the Spotify player. Please check your connection and try again."
}
```

---

## WebView Screen: Known Limitation

The WebView player screen embeds `https://open.spotify.com/embed/track/<id>` via
`flutter_inappwebview`. The iframe renders the Spotify embed UI (album art, controls) visually, but
**audio will not play** because:

- **Android**: `android.webkit.WebView` does not expose Widevine EME (required for DRM audio decryption).
- **iOS**: `WKWebView` does not support Widevine (Apple uses FairPlay exclusively; WKWebView does not expose it).

The `WebViewLimitationBanner` widget (FR-025) displays a persistent, localised notice explaining
this. No raw error codes or stack traces are shown to the user (FR-016).

Queue navigation (prev/next) works by calling `InAppWebViewController.loadUrl()` with the new
track's embed URL. The iframe re-renders with the new track's metadata.

---

## Test Checklist

### Native player screen — widget tests (unchanged)

- `PlayerScreen` loading / data / error states
- Seek bar optimistic drag
- Prev/next button disabled at queue boundaries
- Album art placeholder on image load failure

### WebView player screen — widget tests (new)

- `PlayerWebViewScreen` loading state (metadata fetch in progress)
- `PlayerWebViewScreen` data state (iframe loaded; limitation banner visible)
- `PlayerWebViewScreen` error state (iframe load error; retry button visible)
- `PlayerWebViewScreen` prev tap → iframe URL updates to previous track
- `PlayerWebViewScreen` next tap → iframe URL updates to next track
- Prev button disabled on first track; next button disabled on last track
- `WebViewLimitationBanner` renders localised string (no raw keys)
- `SpotifyIframeWidget` calls `onLoaded` on `onLoadStop`; calls `onError` on `onLoadError`

### Backend contract tests (unchanged)

- `POST /v1/auth/spotify/token` — 200, 400, 401, 503
- `POST /v1/auth/spotify/refresh` — 200, 401
- `GET /v1/tracks/{id}` — 200, 401, 404, 503