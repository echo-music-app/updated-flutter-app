# Research: Spotify Player PoC

**Branch**: `004-spotify-player-poc` | **Date**: 2026-02-28 (updated 2026-03-01)

---

## 1. Spotify Flutter SDK

**Decision**: Use `spotify_sdk ^3.0.2` (community Flutter plugin wrapping the official Spotify Android App Remote SDK
and SpotifyiOS framework).

**Rationale**: There is no official Spotify Flutter SDK. `spotify_sdk` is the de facto standard with active
maintenance (last release October 2024), supports both Android and iOS, and requires no manual AAR management (Android
SDK comes from Maven Central). It exposes `PlayerApi`, `ImagesApi`, `ConnectApi`, and a `Stream<PlayerState>` for
real-time playback state.

**Alternatives considered**:

- `spotikit` — far less adoption, experimental.
- Direct platform channel against native SDKs — same underlying limitations, far more effort.
- Web API only (no SDK) — no real-time playback control.

**Caveats**:

- **Spotify Premium required** for on-demand single-track URI playback on all platforms. Free accounts cannot play a
  specific track URI; a clear in-app message is required (FR-017).
- **iOS**: The native Spotify iOS SDK automatically begins playback the moment the SDK connects. The only workaround (
  passing an invalid URI during connection) is an undocumented hack. Accepted for the PoC.
- **iOS**: Token persistence is reportedly buggy in the native iOS SDK with random disconnections.
- **Android**: The Spotify app must be installed on the device. The SHA-1 signing fingerprint must be registered in the
  Spotify Developer Portal.

---

## 2. Playback State: `Stream<PlayerState>`

**Decision**: Use `SpotifySdk.subscribePlayerState()` which returns a `Stream<PlayerState>`. The SDK is the single
source of truth for playback state (aligned with clarification Q4). No polling.

**Key `PlayerState` fields**:

| Field                  | Type                 | Description                         |
|------------------------|----------------------|-------------------------------------|
| `isPaused`             | `bool`               | True when paused                    |
| `playbackPosition`     | `int` (ms)           | Current position                    |
| `track.name`           | `String`             | Track title                         |
| `track.uri`            | `String`             | Spotify URI                         |
| `track.duration`       | `int` (ms)           | Duration                            |
| `track.artist.name`    | `String`             | Primary artist                      |
| `track.imageUri`       | `ImageUri`           | Resolve via `SpotifySdk.getImage()` |
| `playbackRestrictions` | `PlayerRestrictions` | What operations are allowed         |

**Caveats**:

- The SDK does **not** push continuous position updates. It fires on state transitions (play/pause/seek/track change). A
  `Timer.periodic` must be used to interpolate seek bar position between events.
- `PlayerState` from `spotify_sdk` may not have public constructors (deserialized from native). The data layer must
  expose a project-defined `TrackPlaybackState` model wrapping the SDK type, so tests never touch the SDK directly.

---

## 3. Spotify Web Playback SDK in Flutter WebView — FEASIBILITY ANALYSIS

**Decision**: The Spotify Web Playback SDK **cannot be used for audio playback inside a Flutter WebView** on Android
or iOS. This is a hard platform constraint.

### Why it fails

The Spotify Web Playback SDK is a JavaScript library that streams DRM-protected audio using Widevine EME (Encrypted
Media Extensions). Both Android `WebView` and iOS `WKWebView` — the platform components used by `webview_flutter` and
`flutter_inappwebview` — do not provide Widevine:

| Platform | WebView Component | Widevine EME Available? | Web Playback SDK Works? |
|----------|-------------------|-------------------------|-------------------------|
| Android  | `android.webkit.WebView` | ❌ Disabled; no supported enable path | ❌ Fails at init |
| iOS      | `WKWebView`              | ❌ Not available (Apple uses FairPlay only) | ❌ Fails at init |
| Desktop Chrome | Full Chromium | ✅ Widevine L1/L3 | ✅ Works |

The SDK throws `"Failed to instantiate player"` or refuses to initialize silently when EME is absent. There is no
configuration option or package that enables Widevine in an Android `WebView`.

### Workarounds evaluated

| Approach | Verdict |
|----------|---------|
| Spotify Web Playback SDK in `flutter_inappwebview` | ❌ Blocked by Widevine |
| Spotify Web Playback SDK in `webview_flutter` | ❌ Same WebView component |
| Spotify iframe embed (`open.spotify.com/embed/track/<id>`) | ❌ iframe also requires Widevine for audio in WebView; limited postMessage API; no bidirectional control |
| Crosswalk (embedded Chromium) | ❌ Deprecated 2017 |
| GeckoView (Mozilla) | ❌ No Flutter plugin; uncertain Widevine support |
| Backend audio proxy | ❌ Violates Spotify Terms of Service |
| Chrome Custom Tabs (open Chrome for audio) | ❌ No JS bridge; cannot integrate with app UI |

### Viable hybrid: WebView shell UI + App Remote audio

What _is_ viable is a **hybrid architecture**:

- **Visual layer**: `flutter_inappwebview` loads a **local HTML/CSS/JS shell** (`assets/web/spotify_player.html`)
  that renders the player controls (track info, seek bar, buttons) using web technologies. No audio streaming.
- **Audio layer**: `spotify_sdk` App Remote continues to control audio. The Spotify app plays audio.
- **Bridge layer**: `SpotifyWebViewBridge` (a `flutter_inappwebview` named handler channel) connects the two
  layers bidirectionally.

This approach satisfies the user intent (WebView-embedded player UI) while accepting the platform reality (audio must
go through the Spotify app via App Remote).

### Alternative: Web API Spotify Connect (no SDK)

If removing `spotify_sdk` entirely is a hard requirement, the only alternative is:

- Use the **Spotify Web API Connect endpoints** (`PUT /v1/me/player/play`, etc.) to remote-control whichever Spotify
  Connect device the user has active (their phone, a speaker, etc.).
- This does **not** require the Spotify app to be "integrated" with the Flutter app — it sends HTTP commands to
  Spotify's servers, which forward them to the active device.
- **Significant UX degradation**: requires the user to have Spotify already open on some device; cannot guarantee the
  mobile device is the active player; no guaranteed real-time state callbacks (must poll
  `GET /v1/me/player` or use Spotify Connect WebSocket).
- Not recommended for this PoC.

---

## 4. Spotify Web API HTTP Client

**Decision**: Use `dio` with a Bearer token `Interceptor` for all Spotify Web API calls from the Flutter app.

**Rationale**: `dio` interceptors cleanly attach `Authorization: Bearer <token>` globally and handle 401 refresh retries
in one place. `http` package requires per-request token attachment and has no built-in interceptor model.

**Alternatives considered**:

- `http` package — adequate for a single endpoint but no interceptor; rejected once token refresh logic is needed.
- `spotify` Dart package — typed client but couples to its own release cadence; inflexible for the backend-proxy auth
  model.

**Caveats**:

- Spotify returns `429 Too Many Requests` with `Retry-After` header. Implement backoff responding to 429. PoC scale
  makes hitting limits unlikely.
- As of May 2025, Spotify restricted extended Web API quota to established apps; development mode is sufficient for the
  PoC.

---

## 5. OAuth 2.0 PKCE Flow + Backend Token Proxy

**Decision**: PKCE + backend proxy (aligned with clarification Q2). Mobile generates `code_verifier` and
`code_challenge`. Backend performs the Spotify token exchange using `code` + `code_verifier` + `client_secret`. Mobile
receives an opaque Echo session token and never sees Spotify credentials.

**Redirect URI**: Use HTTPS + Android App Links / iOS Universal Links via `app_links` package. Custom URI schemes (e.g.,
`echo://callback`) are documented but have been actively broken for some apps since Spotify's April 2025 security
enforcement. The backend must serve `/.well-known/assetlinks.json` (Android) and
`/.well-known/apple-app-site-association` (iOS).

**Spotify OAuth endpoints**:

- `https://accounts.spotify.com/authorize` — initiated by mobile only
- `https://accounts.spotify.com/api/token` — called by backend only
- `https://api.spotify.com/v1/me` — called by backend to identify user (requires `user-read-private` + `user-read-email`
  scopes)

**Backend endpoints**:

- `POST /v1/auth/spotify/token` — receives `{ code, code_verifier, redirect_uri }` from mobile; exchanges with Spotify;
  issues Echo opaque token pair
- `POST /v1/auth/spotify/refresh` — mobile sends Echo refresh token; backend proactively refreshes Spotify token if
  within expiry window; rotates Echo token pair

**Alternatives considered**:

- Backend-initiated flow — adds a round-trip; breaks PKCE threat model. Rejected.
- Mobile-only PKCE (no backend) — `client_secret` would be in the APK or absent; violates constitution and FR-014.
  Rejected.
- Custom URI scheme — broken in practice post-April 2025 for some apps. Rejected.

**Caveats**:

- `redirect_uri` must match exactly in `/authorize`, `/api/token`, and the Spotify Developer Dashboard registration.
- Spotify refresh tokens do not expire on a fixed schedule; handle `401` from Spotify on refresh by clearing credentials
  and forcing re-login.

---

## 6. Backend HTTP Client for Spotify API Calls

**Decision**: `httpx.AsyncClient` (shared lifespan instance). Move `httpx` from `dev` to `dependencies` in
`pyproject.toml`.

**Rationale**: `httpx` is already present as a dev dependency. It is the standard async HTTP client in the FastAPI
ecosystem. Synchronous clients (`requests`) would block the event loop. `aiohttp` would add a new dependency with no
advantage.

**Caveats**:

- Set explicit timeouts (`connect=5s`, `read=10s`).
- Handle Spotify `429` and surface a `503` to the mobile rather than propagating the raw error.
- Use separate client instances (or full URLs without `base_url`) for `accounts.spotify.com` vs `api.spotify.com`.

---

## 7. Spotify Token Storage (Backend)

**Decision**: New `spotify_credentials` PostgreSQL table with AES-256-GCM encryption for `access_token` and
`refresh_token` columns. Encryption key from `SPOTIFY_TOKEN_ENCRYPTION_KEY` env var (added to `Settings` as
`SecretStr`).

**Schema (conceptual)**:

```
spotify_credentials
  id              UUID PK
  user_id         UUID FK → users.id UNIQUE
  access_token    BYTEA  (AES-256-GCM ciphertext)
  refresh_token   BYTEA  (AES-256-GCM ciphertext)
  token_expiry    TIMESTAMPTZ (plaintext, for proactive refresh logic)
  spotify_user_id VARCHAR UNIQUE (for upsert on re-auth)
  scope           TEXT
  created_at, updated_at TIMESTAMPTZ
```

**Rationale**: Spotify refresh tokens are effectively permanent per-user credentials. Storing plaintext would mean a DB
breach permanently exposes all users' Spotify accounts. Application-layer AES-256-GCM (via `cryptography` library) keeps
the key out of the DB server's reach. Consistent with existing `AccessToken`/`RefreshToken` pattern in the project.

**Alternatives considered**:

- Plaintext storage — rejected; refresh tokens are long-lived high-value secrets.
- `pgcrypto` — key travels to DB server; worse threat model. Rejected.
- Redis cache for access token — valid production optimisation; add on top later. Out of scope for PoC.

**Caveats**:

- Design versioned key envelope from day one (key version prefix on ciphertext) to make key rotation tractable.
- `SPOTIFY_TOKEN_ENCRYPTION_KEY` must be distinct from `SECRET_KEY`.
- On Spotify refresh token rejection (user revoked), delete the `spotify_credentials` row and return `401` with a
  specific error code so the mobile re-initiates login.

---

## 8. Flutter State Management + WebView Bridge

**Decision**: `PlayerController extends ChangeNotifier` (injected via constructor) + `ListenableBuilder` in the
widget — unchanged from the original plan. Added: `SpotifyWebViewBridge` as a new injectable dependency.

**Architecture**:

```
PlayerController
  ├── subscribes to SpotifySdk.subscribePlayerState() → TrackPlaybackState (SDK source of truth)
  ├── holds SpotifyWebViewBridge → pushes state updates into WebView via callAsyncJavaScriptFunction
  └── receives user commands from WebView via bridge events → forwards to SpotifySdk.*
```

**`SpotifyWebViewBridge`**:

- Wraps `flutter_inappwebview`'s `InAppWebViewController`.
- Exposes `Stream<BridgeEvent> events` for Dart consumers.
- Exposes `Future<void> sendCommand(String type, Map params)` for Dart → JS calls.
- Registers handlers (`onWebViewCreated`) for `bridgeEvent` and `getAccessToken`.
- Requires `AutomaticKeepAliveClientMixin` on `WebViewPlayerWidget` state to prevent WebView recreation.

**Caveats**:

- `SpotifyWebViewBridge.dispose()` must close `StreamController` and null `_controller`.
- `callAsyncJavaScriptFunction` overhead: ≤10 ms per call at 500 ms position update interval — acceptable.
- JS handlers must be registered in `onWebViewCreated` (before page load) to be available during init.

---

## 9. WebView JS Bridge: flutter_inappwebview vs webview_flutter

**Decision**: `flutter_inappwebview ^6.1.0`. `webview_flutter` is insufficient.

**Rationale**:

| Requirement | `webview_flutter` | `flutter_inappwebview` |
|-------------|-------------------|------------------------|
| Dart → JS return value | ❌ No | ✅ `callAsyncJavaScriptFunction` |
| JS → Dart with return value | ❌ `JavaScriptChannel` one-way only | ✅ Named handlers with `Future` return |
| Load local asset HTML | ✅ `loadFlutterAsset()` | ✅ `loadFile()` |
| `getOAuthToken` callback pattern | ❌ Cannot return value to JS | ✅ Handler return resolves as JS Promise |

The `getAccessToken` handler pattern requires `flutter_inappwebview`: JS calls a handler and awaits a returned token.
`webview_flutter`'s `JavaScriptChannel` cannot return values to JavaScript.

---

## 10. Seek Bar

**Decision**: Flutter's built-in `Slider` widget with optimistic local `_dragPosition` in `PlayerController`. Time
formatted as `mm:ss` via a pure `_formatMs(int ms)` utility function.

**Optimistic drag pattern**:

- On `onChangeStart`: set `_isDragging = true`, record local position.
- On `onChanged`: update local position only (no SDK call).
- On `onChangeEnd`: call `SpotifySdk.seekTo(positionMs)`; keep `_isDragging = true` until next SDK state event confirms
  the new position.
- While `_isDragging`, suppress incoming SDK position updates to prevent thumb snap-back.

**Alternatives considered**:

- `audio_video_progress_bar` package — buffering concept doesn't apply to Spotify SDK; extra dependency. Rejected.
- `CustomPainter` — 3–5x more code for no visual benefit in a PoC. Rejected.

---

## 11. Album Art Loading

**Decision**: Add `cached_network_image ^3.4.0` to `pubspec.yaml`. Use `CachedNetworkImage` with `placeholder` and
`errorWidget` callbacks showing `AlbumArtPlaceholder`.

**Rationale**: `Image.network` re-downloads on every rebuild. The seek bar drives frequent rebuilds via the
`Timer.periodic` position interpolation. `CachedNetworkImage` writes to disk cache — image is served instantly on
subsequent rebuilds and after app restarts.

**Caveats**:

- `SpotifySdk.getImage()` returns a `Uint8List`, not an HTTP URL. The data layer must resolve Spotify `imageUri` values
  to CDN URLs (`https://i.scdn.co/image/<id>`) before passing to `CachedNetworkImage`. Alternative: use `Image.memory`
  for SDK-resolved images and `CachedNetworkImage` only for Web API URLs.
- In widget tests, use the `errorWidget` path (network unavailable) or pass a fake `BaseCacheManager`.

---

## 12. Login Screen Navigation

**Decision**: Dedicated login screen (separate route); both player screens show explicit
loading → data → error states. Login screen offers two navigation options after auth.

**Navigation flow**:

```
App launch → check for stored Echo token
  ├─ No token → navigate to SpotifyLoginScreen
  │     ├─ "Open Player" → OAuth → /player (replace)
  │     └─ "Open WebView Player" → OAuth → /player-webview (replace)
  └─ Token present → navigate to stored destination
        ├─ /player
        │    ├─ Metadata loading → loading state
        │    ├─ Fetch success → data state (full native SDK player UI)
        │    └─ Fetch error → error state (human-readable message + retry)
        └─ /player-webview
             ├─ Metadata loading → loading state
             ├─ Fetch + iframe load success → data state (iframe + limitation banner)
             └─ Fetch or iframe error → error state (human-readable message + retry)
```

**Routes to register in `AppRouter`**:

- `/login` → `SpotifyLoginScreen`
- `/player` → `PlayerScreen` (existing — unchanged)
- `/player-webview` → `PlayerWebViewScreen` (new)