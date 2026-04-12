# Feature Specification: Spotify Player PoC Screen

**Feature Branch**: `004-spotify-player-poc`
**Created**: 2026-02-28
**Status**: Draft
**Input**: User description: "create a screen in the mobile app that demonstrates how spotify tracks can be played (
PoC). It should have the following controls: previous queue item, play/pause next queue item, seek bar, name of the
track, the artist, and album cover. the track being played / displayed can be hardcoded at first, but only in the data
layer, not in the UI"

## Clarifications

### Session 2026-02-28

- Q: What does "Spotify API integration" mean for this PoC? → A: Spotify Web API + Spotify Mobile SDK (metadata fetched from Spotify Web API; actual audio playback controlled via Spotify Android/iOS SDK)
- Q: How should Spotify OAuth tokens be managed relative to the project constitution? → A: Introduce a minimal Echo backend proxy to stay constitution-compliant from day one (token issuance and refresh handled server-side; mobile treats tokens as opaque strings)
- Q: What is the source of the playback queue? → A: Hardcoded list of Spotify track URIs in the data layer (repository/mock); all display metadata fetched from the Spotify Web API at runtime
- Q: What is the source of truth for playback state (seek position, play/pause, current track)? → A: Spotify SDK state callbacks are the single source of truth; UI updates on every SDK event (optimistic local updates permitted for responsiveness but must be reconciled with SDK state)
- Q: Where does the login flow live and what does the player show during metadata fetch? → A: Separate dedicated login screen; player screen shows explicit loading state while fetching metadata and error state on failure

### Session 2026-03-01

- Q: How does the user navigate to the new WebView player screen? → A: Separate route `/player-webview` accessible from the login screen (user chooses on login)
- Q: What controls must the WebView player screen expose? → A: Full parity — same controls as existing screen (play/pause, prev/next, seek bar, album art, track name, artist)
- Q: Does the WebView player screen use the same `spotify_sdk` for audio, or is it audio-free? → A: Spotify iframe embed (`open.spotify.com/embed/track/<id>`) — audio will not function in a WebView (Widevine EME unavailable); this is an explicit PoC to demonstrate and document the iframe approach and its limitations
- Q: Must the WebView screen meet the same success criteria (SC-001 through SC-008) as the existing screen? → A: Yes — same criteria apply; SC-002/SC-003/SC-004 results will document actual iframe behaviour vs. targets (expected: not met for audio-dependent criteria)
- Q: How is the WebView screen identified to the user in the UI? → A: Same label as existing screen — no visual distinction; screens are differentiated only by their route paths (`/player` vs. `/player-webview`)

## User Scenarios & Testing *(mandatory)*

### User Story 6 - Access WebView Player Screen (Priority: P2)

As a user on the login screen, I can choose to open the WebView player screen (`/player-webview`) as an alternative to the existing native SDK player screen (`/player`). Both screens share the same label and visual identity; the only distinction is the route path.

**Why this priority**: The WebView screen is a parallel PoC track. It must be reachable independently from the login screen to allow side-by-side comparison with the native SDK screen without altering the existing user flow.

**Independent Test**: From the login screen, navigate to `/player-webview`; confirm the screen loads and displays the Spotify iframe embed with the same control layout as the native player screen.

**Acceptance Scenarios**:

1. **Given** the user is authenticated, **When** they navigate to `/player-webview` from the login screen, **Then** the WebView player screen loads with the Spotify iframe embed visible.
2. **Given** the WebView player screen is open, **When** it loads, **Then** all controls (play/pause, prev/next, seek bar, album art, track name, artist) are rendered at full parity with the native player screen layout.
3. **Given** the WebView player screen is open, **When** audio playback is attempted via the iframe, **Then** the screen documents and displays a clear limitation message explaining that audio is not supported in the WebView context (Widevine EME unavailable).
4. **Given** the user is on the WebView player screen, **When** they navigate back, **Then** they return to the login screen without affecting the state of the native player screen.

---

### User Story 1 - View Now Playing Track Info (Priority: P1)

As a user, I open the player screen and immediately see the current track's album cover, track name, and artist name
displayed prominently. The information is fetched from the Spotify Web API, giving me confidence that the integration is real.

**Why this priority**: Track identification is the foundation of a music player — without it, no other control makes
sense. It establishes the PoC's core visual layout and validates the Spotify Web API connection.

**Independent Test**: Open the player screen; verify album art, track name, and artist are displayed correctly with data sourced from the Spotify Web API (not hardcoded in the UI).

**Acceptance Scenarios**:

1. **Given** the player screen is open, **When** it loads, **Then** the album cover image is visible and fills an
   appropriate area of the screen.
2. **Given** the player screen is open, **When** it loads, **Then** the track name and artist name are displayed as
   readable text below the album art.
3. **Given** the player screen has loaded, **When** a reviewer inspects the data layer, **Then** all track metadata originates from the Spotify Web API response, not from hardcoded UI values.

---

### User Story 2 - Authenticate with Spotify (Priority: P1)

As a user, I must log in with my Spotify account before the player screen becomes accessible. The app uses the Spotify OAuth 2.0 flow to obtain an access token required for both API calls and SDK playback.

**Why this priority**: Authentication gates all Spotify API and SDK usage; without it, no real integration is possible. It must be implemented before any other Spotify-dependent story.

**Independent Test**: Launch the app; confirm the Spotify login flow appears, complete it, and confirm the player screen becomes accessible with a valid session.

**Acceptance Scenarios**:

1. **Given** the user has not authenticated, **When** they open the app, **Then** they are navigated to a dedicated Spotify login screen (not an overlay on the player).
2. **Given** the user completes Spotify OAuth login, **When** the token is received, **Then** the app navigates to the player screen, which displays a loading state while fetching track metadata.
3. **Given** metadata fetch completes successfully, **When** the player screen receives data, **Then** it transitions from loading state to the full player UI.
4. **Given** metadata fetch fails, **When** an error is returned, **Then** the player screen displays a human-readable error state with a retry option.
5. **Given** the access token expires, **When** any Spotify API or SDK call is made, **Then** the token is refreshed transparently without requiring the user to log in again.

---

### User Story 3 - Play and Pause via Spotify SDK (Priority: P2)

As a user, I can tap a play/pause button to start or stop playback of the current track through the Spotify SDK. The button reflects the current playback state so I always know whether music is playing.

**Why this priority**: Play/pause is the most fundamental control; it validates that the Spotify Mobile SDK is correctly integrated and responding to commands.

**Independent Test**: Tap play; confirm Spotify SDK begins playback and button icon changes to pause. Tap again; confirm playback stops and button returns to play icon.

**Acceptance Scenarios**:

1. **Given** the track is paused, **When** I tap the play button, **Then** the Spotify SDK begins playback and the button changes to a pause icon.
2. **Given** the track is playing, **When** I tap the pause button, **Then** the Spotify SDK pauses playback and the button changes to a play icon.
3. **Given** the track finishes, **When** playback ends, **Then** the button returns to the play icon and the seek bar returns to the beginning.

---

### User Story 4 - Seek Through the Track (Priority: P3)

As a user, I can drag a seek bar to jump to any position in the track. The current elapsed time and total duration are
shown, so I know where I am in the song.

**Why this priority**: Seeking demonstrates real-time playback state management via the Spotify SDK, a key part of the PoC's technical validation.

**Independent Test**: While track is playing, drag the seek bar to 50%; confirm Spotify SDK seeks to the midpoint and elapsed time updates accordingly.

**Acceptance Scenarios**:

1. **Given** a track is playing, **When** the seek bar is visible, **Then** it advances in real time reflecting playback
   progress reported by the Spotify SDK.
2. **Given** the player screen is open, **When** I drag the seek bar thumb to a new position, **Then** the Spotify SDK seeks to that position.
3. **Given** the seek bar is being dragged, **When** I release it, **Then** playback continues from the new position
   without stutter.

---

### User Story 5 - Navigate the Queue (Priority: P4)

As a user, I can tap "previous" or "next" buttons to move to the adjacent track in the queue. All track information (
album art, name, artist) updates to reflect the newly selected track fetched from the Spotify Web API.

**Why this priority**: Queue navigation proves the data layer can fetch multiple tracks from Spotify and the UI can reflect state changes, validating the PoC end-to-end.

**Independent Test**: Tap next; verify track info updates with Spotify Web API data for the next queued track. Tap previous; verify it returns to the first track.

**Acceptance Scenarios**:

1. **Given** there is a next track in the queue, **When** I tap the next button, **Then** the Spotify SDK skips to the next track and the UI fetches and displays updated metadata from the Spotify Web API.
2. **Given** I am on the first track in the queue, **When** I tap the previous button, **Then** the button is disabled
   or has no effect (no wrapping to end of queue).
3. **Given** I am on the last track in the queue, **When** I tap the next button, **Then** the button is disabled or has
   no effect.
4. **Given** a track is playing and I tap next, **When** the new track loads, **Then** playback begins automatically
   from the start of the new track via the Spotify SDK.

---

### Edge Cases

- What happens when the album cover image fails to load? A placeholder or default image must be shown.
- What happens if the queue has only one track? Both previous and next buttons are disabled.
- What happens if the seek bar is dragged while the track is paused? The position updates but playback remains paused;
  when play is tapped, it resumes from the new position.
- What happens on very short tracks (under 10 seconds)? Controls still function correctly without layout issues.
- What happens when the Spotify access token expires mid-session? The token must be refreshed transparently.
- What happens if the Spotify SDK or Web API returns an error? A user-readable error state must be shown (no raw error codes or stack traces).
- What happens if the user does not have a Spotify Premium account? The Spotify Mobile SDK requires Premium for playback; the app must display a clear, human-readable message explaining the requirement.
- What happens when the user navigates from the login screen to `/player-webview` and then back? The native player screen state at `/player` is unaffected; the WebView screen is destroyed and recreated on next visit.
- What happens if the Spotify iframe fails to load in the WebView? The WebView player screen MUST show its error state with a human-readable message and retry option.
- What happens when the user attempts audio playback via the iframe in the WebView? The limitation notice (FR-025) is displayed; no silent failure or raw error is shown.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The player screen MUST display the current track's album cover image prominently.
- **FR-002**: The player screen MUST display the current track's name and artist name as readable text.
- **FR-003**: The player screen MUST include a play/pause toggle button that reflects the current playback state.
- **FR-004**: The player screen MUST include a seek bar that shows playback progress in real time and allows the user to
  scrub to any position.
- **FR-005**: The player screen MUST display elapsed time and total track duration alongside the seek bar.
- **FR-006**: The player screen MUST include a "next" button that advances to the next item in the queue via the Spotify SDK.
- **FR-007**: The player screen MUST include a "previous" button that moves to the previous item in the queue via the Spotify SDK.
- **FR-008**: The next and previous buttons MUST be disabled (or visually inactive) when no further item exists in the
  respective direction.
- **FR-009**: When the user navigates to a different track, all displayed information (album art, track name, artist)
  MUST update to reflect the new track fetched from the Spotify Web API.
- **FR-010**: Track metadata MUST be fetched from the Spotify Web API; the UI MUST NOT contain hardcoded track values.
- **FR-011**: When playback ends naturally, the seek bar MUST reset to the start and the play button MUST return to its
  play state.
- **FR-012**: If the album art cannot be loaded, a fallback placeholder image MUST be displayed.
- **FR-013**: The app MUST authenticate the user via Spotify OAuth 2.0 before accessing any Spotify API or SDK functionality.
- **FR-014**: Token issuance, refresh, and revocation MUST be handled by the Echo backend; the mobile app MUST treat the access token as an opaque string and MUST store it using platform-native secure storage.
- **FR-015**: Audio playback MUST be controlled exclusively through the Spotify Mobile SDK (Android/iOS); direct audio streaming is out of scope.
- **FR-016**: If the Spotify SDK or Web API returns an error, the screen MUST display a human-readable error state; raw error codes and stack traces MUST NOT be shown to the user.
- **FR-017**: If the user does not have a Spotify Premium account, the app MUST display a clear message explaining that Premium is required for playback.
- **FR-018**: The Echo backend MUST expose an endpoint that completes the Spotify OAuth PKCE exchange and returns an opaque token to the mobile app; the Spotify client secret MUST NOT be present in the mobile app.
- **FR-019**: The player screen MUST subscribe to Spotify SDK state callbacks and update all playback-related UI (seek bar position, play/pause icon, current track info) in response to those events; the SDK is the single source of truth for playback state.
- **FR-020**: A dedicated login screen MUST be shown to unauthenticated users; the player screen MUST NOT be accessible before authentication completes.
- **FR-021**: The player screen MUST explicitly handle three states: loading (while fetching metadata), error (fetch or SDK failure with retry option), and data (fully loaded player UI).
- **FR-022**: A second, separate WebView player screen MUST be implemented at route `/player-webview`; the existing native SDK screen at route `/player` MUST remain unchanged.
- **FR-023**: The WebView player screen MUST be navigable from the login screen independently of the native player screen.
- **FR-024**: The WebView player screen MUST embed the Spotify iframe (`open.spotify.com/embed/track/<id>`) and expose full parity controls (play/pause, prev/next, seek bar, album art, track name, artist) at the same layout as the native player screen.
- **FR-025**: The WebView player screen MUST display a visible, human-readable limitation notice explaining that audio playback is not supported in the WebView context due to platform DRM constraints (Widevine EME unavailable in Android WebView and iOS WKWebView).
- **FR-026**: The WebView player screen MUST carry no visual distinction from the native player screen in terms of screen title or branding; screens are differentiated only by their route paths.
- **FR-027**: The WebView player screen MUST apply the same three UI states (loading, error, data) as the native player screen (FR-021).
- **FR-028**: All SC-001 through SC-008 success criteria apply to the WebView player screen; where audio-dependent criteria (SC-002, SC-003) cannot be met due to the iframe limitation, the deviation MUST be documented in the screen's error/limitation state rather than left as a silent failure.

### Key Entities

- **Track**: A single playable item with a name, artist name, album cover image URL, duration, and Spotify track URI. Sourced from the Spotify Web API.
- **Queue**: An ordered list of Tracks with a pointer to the currently active Track.
- **PlaybackState**: The current runtime state of the player, including whether it is playing or paused, the current seek position, and the active Track. The Spotify SDK state callbacks are the single source of truth; any optimistic local updates must be reconciled against incoming SDK events.
- **SpotifySession**: The authenticated Spotify session. The Echo backend manages token issuance and refresh; the mobile app holds only an opaque access token stored in platform-native secure storage.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: All player controls (play/pause, previous, next, seek) are visible and operable without scrolling on
  standard phone screen sizes.
- **SC-002**: Tapping play/pause produces a visible state change (button icon update) within 100 ms of the tap.
- **SC-003**: Dragging and releasing the seek bar results in the Spotify SDK seeking to the correct position within 500 ms.
- **SC-004**: Tapping next or previous updates all displayed track information within 300 ms of the Spotify Web API response.
- **SC-005**: The screen renders correctly across both Android and iOS form factors without layout overflow or clipping.
- **SC-006**: A developer reviewer can identify the data-layer boundary and confirm zero hardcoded track values exist in the UI layer.
- **SC-007**: The Spotify OAuth flow (including backend token exchange) completes successfully and the player screen becomes accessible within 5 seconds of the user granting permission.
- **SC-008**: Access token expiry is handled transparently — the user is never shown a login prompt during an active session unless their Spotify authorization has been revoked.

## Assumptions

- The PoC uses the Spotify Web API (metadata: track name, artist, album art URL, duration) and the Spotify Mobile SDK (Android/iOS) for audio playback control.
- Track queue data is sourced from the Spotify Web API; the data layer may use a hardcoded list of Spotify track URIs as the initial queue, but all display metadata is fetched from the API — never hardcoded in the UI.
- The minimum queue size for the PoC is 2 tracks so that queue navigation can be demonstrated.
- Spotify Premium is required for SDK playback; the app will surface a clear message if the user's account does not qualify.
- The Spotify OAuth 2.0 PKCE flow is used for authentication. The Echo backend handles the token exchange with Spotify's authorization server and manages token refresh; the mobile app receives and stores only an opaque access token in platform-native secure storage.
- Playback controls follow standard mobile music player conventions (Material Design / Cupertino patterns as appropriate to the platform).
- The Echo backend exposes a minimal auth proxy for this PoC — sufficient to complete the Spotify OAuth exchange and issue/refresh tokens — keeping the Spotify client secret server-side in compliance with the project constitution.
- The WebView player screen (`/player-webview`) is a parallel PoC track alongside the existing native SDK player screen (`/player`); both screens coexist and are independently accessible from the login screen.
- The Spotify iframe embed (`open.spotify.com/embed/track/<id>`) will render visually in the WebView but audio playback will not function due to Widevine EME unavailability in Android `WebView` and iOS `WKWebView`; this limitation is a known and accepted PoC constraint, documented in FR-025.
- The two player screens share no visual distinction in title or branding; they are differentiated only by route path.