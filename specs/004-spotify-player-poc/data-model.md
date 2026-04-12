# Data Model: Spotify Player PoC

**Branch**: `004-spotify-player-poc` | **Date**: 2026-02-28 (updated 2026-03-01)

---

## Entities

### 1. `Track` (Mobile — data layer model)

Represents a single Spotify track. Populated by the Spotify Web API (`GET /v1/tracks/{id}`). The data layer holds a
hardcoded list of Spotify track URIs; all display fields are fetched from the API.

| Field         | Type     | Source                 | Notes                                                                                            |
|---------------|----------|------------------------|--------------------------------------------------------------------------------------------------|
| `id`          | `String` | Spotify Web API        | Spotify track ID (e.g., `4iV5W9uYEdYUVa79Axb7Rh`)                                                |
| `uri`         | `String` | Data layer (hardcoded) | Spotify URI (e.g., `spotify:track:4iV5W9uYEdYUVa79Axb7Rh`); the only field that may be hardcoded |
| `name`        | `String` | Spotify Web API        | Track title; MUST NOT be hardcoded in the UI                                                     |
| `artistName`  | `String` | Spotify Web API        | Primary artist display name                                                                      |
| `albumArtUrl` | `String` | Spotify Web API        | CDN image URL (`https://i.scdn.co/image/<id>`); largest available image                          |
| `durationMs`  | `int`    | Spotify Web API        | Total duration in milliseconds                                                                   |

**Validation**:

- `durationMs` MUST be > 0.
- `albumArtUrl` may be empty/null; the UI falls back to `AlbumArtPlaceholder` (FR-012).

---

### 2. `Queue` (Mobile — data layer model)

An ordered list of `Track` items with a cursor to the currently active track. Shared between both
player screens — the native SDK screen and the WebView iframe screen use the same `Queue` instance
via `SpotifyQueueRepository`.

| Field          | Type          | Notes                        |
|----------------|---------------|------------------------------|
| `tracks`       | `List<Track>` | Minimum 2 items for the PoC  |
| `currentIndex` | `int`         | Index into `tracks`; 0-based |

**Derived properties**:

- `currentTrack` → `tracks[currentIndex]`
- `hasPrevious` → `currentIndex > 0`
- `hasNext` → `currentIndex < tracks.length - 1`

**State transitions**:

```
skipNext:     currentIndex++ (only if hasNext)
skipPrevious: currentIndex-- (only if hasPrevious)
```

---

### 3. `TrackPlaybackState` (Mobile — presentation model, native SDK screen only)

The runtime playback state exposed by `PlayerController` to the native SDK player screen widget
layer. Derived from Spotify SDK `PlayerState` callbacks. This model is **not used** by the WebView
screen (which has its own `WebViewPlayerState`).

| Field                   | Type                   | Notes                                                                    |
|-------------------------|------------------------|--------------------------------------------------------------------------|
| `isPlaying`             | `bool`                 | `!PlayerState.isPaused`                                                  |
| `positionMs`            | `int`                  | Last known position from SDK (ms); interpolated locally for the seek bar |
| `lastPositionTimestamp` | `DateTime`             | Wall-clock time when `positionMs` was received; used for interpolation   |
| `currentTrack`          | `Track?`               | Null until first SDK event                                               |
| `restrictions`          | `PlaybackRestrictions` | Which controls are currently allowed                                     |

**State transitions** (driven by SDK events):

```
SDK event received → update positionMs + lastPositionTimestamp + isPlaying + currentTrack
User seeks         → positionMs updated optimistically; _isDragging = true
SDK confirms seek  → _isDragging = false; positionMs reconciled with SDK value
Track ends         → positionMs = 0, isPlaying = false
```

---

### 4. `WebViewPlayerState` (Mobile — presentation model, WebView iframe screen only)

The runtime state exposed by `PlayerWebViewScreen`'s stateful widget to its subtree. Managed
entirely in Dart; not derived from the Spotify SDK (audio does not function in WebView).

| Field          | Type     | Notes                                                                     |
|----------------|----------|---------------------------------------------------------------------------|
| `iframeLoaded` | `bool`   | True once `InAppWebView.onLoadStop` fires for the current iframe URL      |
| `iframeError`  | `bool`   | True if `InAppWebView.onLoadError` fires                                  |
| `currentTrack` | `Track?` | The currently displayed track; null until metadata fetch completes        |
| `hasPrevious`  | `bool`   | Derived from `Queue.hasPrevious`; controls prev button enabled state      |
| `hasNext`      | `bool`   | Derived from `Queue.hasNext`; controls next button enabled state          |

**State machine (`PlayerWebViewScreen`)**:

```
           ┌──────────────────────────────────────────┐
           │         PlayerWebViewScreenState          │
           └──────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
      loading              error                 data
  (fetching metadata    (metadata fetch       (iframe visible +
   OR iframe loading)    or iframe error)      limitation banner +
   → CircularProgress    → error msg            prev/next controls)
                          + retry
```

Transitions:

- `Route opened + valid token` → `loading` → fetch queue metadata → set iframe URL → wait for `onLoadStop` → `data`
- `data` + `onLoadError` → `error`
- `error` + retry tap → `loading`
- `data` + prev/next tap → reload iframe with new track URL (stays in `data`; `iframeLoaded = false` briefly)

---

### 5. `SpotifySession` (Mobile — data layer model)

Holds the opaque Echo session token received after Spotify OAuth. The mobile never sees the Spotify access token.
Shared between both player screens.

| Field              | Type     | Notes                                                                   |
|--------------------|----------|-------------------------------------------------------------------------|
| `echoAccessToken`  | `String` | Opaque token issued by Echo backend; stored in `flutter_secure_storage` |
| `echoRefreshToken` | `String` | Opaque refresh token; stored in `flutter_secure_storage`                |

**Storage**: `flutter_secure_storage` (keyed by constants, e.g., `echo_access_token`, `echo_refresh_token`).

---

### 6. `spotify_credentials` (Backend — PostgreSQL table)

Stores Spotify OAuth tokens server-side, associated with an Echo `User`. Spotify tokens are encrypted at rest with
AES-256-GCM. Unchanged from original design.

| Column            | Type           | Constraints             | Notes                                                                    |
|-------------------|----------------|-------------------------|--------------------------------------------------------------------------|
| `id`              | `UUID`         | PK                      | uuid7                                                                    |
| `user_id`         | `UUID`         | FK → `users.id`, UNIQUE | One row per Echo user                                                    |
| `access_token`    | `BYTEA`        | NOT NULL                | AES-256-GCM ciphertext; nonce prepended                                  |
| `refresh_token`   | `BYTEA`        | NOT NULL                | AES-256-GCM ciphertext; nonce prepended                                  |
| `token_expiry`    | `TIMESTAMPTZ`  | NOT NULL                | Plaintext; used for proactive refresh (refresh if within 60 s of expiry) |
| `spotify_user_id` | `VARCHAR(255)` | UNIQUE                  | Spotify's own user ID; used for upsert on re-auth                        |
| `scope`           | `TEXT`         | NOT NULL                | Granted OAuth scope string                                               |
| `created_at`      | `TIMESTAMPTZ`  | NOT NULL DEFAULT now()  |                                                                          |
| `updated_at`      | `TIMESTAMPTZ`  | NOT NULL DEFAULT now()  | Updated on every token refresh                                           |

**Encryption key**: `SPOTIFY_TOKEN_ENCRYPTION_KEY` env var (added to `Settings` as `SecretStr`; versioned envelope
prefix included for key rotation support).

**Upsert behaviour**: On re-authentication by the same Spotify user, update existing row rather than creating a
duplicate (`ON CONFLICT (spotify_user_id) DO UPDATE`).

---

## Relationships

```
Echo User (1) ──── (0..1) spotify_credentials
Queue (1) ──────── (1..*) Track
TrackPlaybackState (1) ── (0..1) Track  [currentTrack] — native screen only
WebViewPlayerState (1) ── (0..1) Track  [currentTrack] — WebView screen only
SpotifySession ─────────── stored in flutter_secure_storage (not a DB entity)
Queue ──────────────────── shared between PlayerScreen and PlayerWebViewScreen
```

---

## Screen State Machines

### Native SDK Screen (`/player` — unchanged)

```
           ┌──────────────────────────────────┐
           │           PlayerScreenState       │
           └──────────────────────────────────┘
                          │
         ┌────────────────┼────────────────┐
         ▼                ▼                ▼
      loading           error            data
  (fetching metadata) (Spotify API     (full player UI:
   → CircularProgress  or SDK error)    album art, controls,
                       → error msg       seek bar)
                         + retry
```

### WebView Iframe Screen (`/player-webview` — new)

```
           ┌──────────────────────────────────────────┐
           │         PlayerWebViewScreenState          │
           └──────────────────────────────────────────┘
                              │
         ┌────────────────────┼────────────────────┐
         ▼                    ▼                    ▼
      loading              error                 data
  (fetching metadata    (metadata fetch       (Spotify iframe embed +
   OR iframe loading)    or iframe error)      WebViewLimitationBanner +
   → CircularProgress    → error msg            prev/next controls)
                          + retry
```