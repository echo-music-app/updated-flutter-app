# Contract: Mobile Music Search + Backend Consumption

**Feature**: `010-mobile-search-screen` | **Date**: 2026-03-22  
**Type**: REST API consumption contract (Echo backend) + Mobile UI/view-model contract (Flutter)

---

## Backend API Consumption

This feature consumes existing authenticated endpoint `POST /v1/search/music`. No backend endpoint changes are introduced in this feature.

### 1) POST `/v1/search/music`

Execute unified multi-type music search.

#### Request

```http
POST /v1/search/music
Authorization: Bearer <echo_access_token>
Accept: application/json
Content-Type: application/json
```

#### Request body

```json
{
  "q": "daft punk"
}
```

Optional field accepted by backend contract:

```json
{
  "q": "daft punk",
  "limit": 20
}
```

#### Request rules

- `q` is required and must be non-empty after trim.
- Mobile sends exactly the user-submitted free-text query as `q`.
- `limit` is optional and may be omitted for default behavior.

#### Response (`200 OK`) consumed fields

```json
{
  "query": "daft punk",
  "limit": 20,
  "tracks": [
    {
      "id": "track:example",
      "type": "track",
      "display_name": "Harder, Better, Faster, Stronger",
      "primary_creator_name": "Daft Punk",
      "duration_ms": 224000,
      "playable_link": "https://open.spotify.com/track/...",
      "artwork_url": "https://...",
      "sources": [
        {
          "source": "spotify",
          "source_item_id": "spotify:track:...",
          "source_url": "https://open.spotify.com/track/..."
        }
      ],
      "relevance_score": 0.97
    }
  ],
  "albums": [],
  "artists": [],
  "summary": {
    "total_count": 1,
    "per_type_counts": {
      "tracks": 1,
      "albums": 0,
      "artists": 0
    },
    "per_source_counts": {
      "spotify": 1,
      "soundcloud": 0
    },
    "source_statuses": {
      "spotify": "matched",
      "soundcloud": "no_matches"
    },
    "is_partial": false,
    "warnings": []
  }
}
```

#### Response mapping rules

- `tracks[]` -> map to `TrackSearchResult` objects.
- `albums[]` -> map to `AlbumSearchResult` objects.
- `artists[]` -> map to `ArtistSearchResult` objects.
- `summary` -> map to `MusicSearchSummary`.
- All three arrays are expected to exist; mobile treats missing arrays as empty lists for defensive parsing.

#### Error mapping

| Status | Mobile behavior |
|---|---|
| `401` | Invoke existing session-clear behavior (`AuthRepository.clearSession()`), clear current search state, show auth-required messaging, and rely on app-router auth guard redirect to `/login` |
| `422` | Show validation error state for submitted query |
| `503` | Show service-unavailable error state with retry |
| `5xx`/network failure | Show retryable transient error state |

---

## Mobile Route Contract

### Routes

| Route | Behavior |
|---|---|
| `/search` | Opens music search screen with query input, segmented result selector, and result list area |

### Entry points

- Home screen exposes navigation action to `/search`.
- Route is protected by existing auth redirect behavior in app router.

---

## Mobile UI Contract

### `MusicSearchViewModel` responsibilities

- Accept free-text query submissions from the search field.
- Validate query is non-empty before repository call.
- Execute repository search and map results to typed objects.
- Track selected segment (`tracks`, `albums`, `artists`) and project visible list accordingly.
- Expose explicit screen states: `idle`, `loading`, `data`, `empty`, `error`, `authRequired`.
- Handle stale-response protection so only latest submitted query updates state.
- Expose retry action that re-runs the latest submitted query.

### `MusicSearchScreen` required states

| State | Required behavior |
|---|---|
| `idle` | Query input visible; prompt to start search |
| `loading` | Query execution indicator visible |
| `data` | Segmented control visible; selected type results rendered |
| `empty` | Segmented control visible; selected type empty-state message |
| `error` | Actionable error message + retry action |
| `authRequired` | Auth-expired message and re-authentication path |

### Segmented control requirements

- Use `SegmentedButton` with exactly three options: `Tracks`, `Albums`, `Artists`.
- Only one segment can be active at a time.
- Segment changes must not trigger a new backend request for the same query.

### Dedicated result widget requirements

- `TrackSearchResultTile` renders track-specific metadata.
- `AlbumSearchResultTile` renders album-specific metadata.
- `ArtistSearchResultTile` renders artist-specific metadata.
- Widget selection is driven solely by active segment type.

### Accessibility and localization

- All user-facing strings come from ARB localization resources.
- Search submit action, segmented control, and retry action expose semantics labels.

---

## Non-Functional Expectations

- Search-to-first-result experience remains responsive on baseline devices.
- Segment switching is instant for already-loaded query results.
- Stale results from previous queries are never shown after a newer query succeeds.
- Error messages are user-readable and do not expose raw backend payloads.
