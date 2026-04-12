# Data Model: Mobile Music Search Screen

**Branch**: `010-mobile-search-screen` | **Date**: 2026-03-22

---

## Entities

### 1. `MusicSearchQuery` (Mobile domain model)

Represents one user-submitted free-text query.

| Field | Type | Notes |
|---|---|---|
| `raw` | `String` | Input exactly as entered by user |
| `trimmed` | `String` | Normalized value sent as `q` |

**Validation**:

- `trimmed` MUST be non-empty.
- Whitespace-only submissions are invalid.

---

### 2. `SearchResultType` (Mobile domain enum)

Represents the active segmented result type.

| Value | Meaning |
|---|---|
| `tracks` | Track results segment |
| `albums` | Album results segment |
| `artists` | Artist results segment |

---

### 3. `ResultAttribution` (Mobile domain model)

Source metadata for one matched result.

| Field | Type | Source |
|---|---|---|
| `source` | `String` | backend `sources[].source` |
| `sourceItemId` | `String` | backend `sources[].source_item_id` |
| `sourceUrl` | `String?` | backend `sources[].source_url` |

---

### 4. `TrackSearchResult` (Mobile domain model)

Typed app object used for track rendering.

| Field | Type | Source |
|---|---|---|
| `id` | `String` | backend `tracks[].id` |
| `displayName` | `String` | backend `tracks[].display_name` |
| `primaryCreatorName` | `String?` | backend `tracks[].primary_creator_name` |
| `durationMs` | `int?` | backend `tracks[].duration_ms` |
| `playableLink` | `String?` | backend `tracks[].playable_link` |
| `artworkUrl` | `String?` | backend `tracks[].artwork_url` |
| `sources` | `List<ResultAttribution>` | backend `tracks[].sources[]` |
| `relevanceScore` | `double` | backend `tracks[].relevance_score` |

---

### 5. `AlbumSearchResult` (Mobile domain model)

Typed app object used for album rendering.

| Field | Type | Source |
|---|---|---|
| `id` | `String` | backend `albums[].id` |
| `displayName` | `String` | backend `albums[].display_name` |
| `primaryCreatorName` | `String?` | backend `albums[].primary_creator_name` |
| `artworkUrl` | `String?` | backend `albums[].artwork_url` |
| `sources` | `List<ResultAttribution>` | backend `albums[].sources[]` |
| `relevanceScore` | `double` | backend `albums[].relevance_score` |

---

### 6. `ArtistSearchResult` (Mobile domain model)

Typed app object used for artist rendering.

| Field | Type | Source |
|---|---|---|
| `id` | `String` | backend `artists[].id` |
| `displayName` | `String` | backend `artists[].display_name` |
| `artworkUrl` | `String?` | backend `artists[].artwork_url` |
| `sources` | `List<ResultAttribution>` | backend `artists[].sources[]` |
| `relevanceScore` | `double` | backend `artists[].relevance_score` |

---

### 7. `MusicSearchSummary` (Mobile domain model)

Response summary metadata consumed for messaging/diagnostics.

| Field | Type | Source |
|---|---|---|
| `totalCount` | `int` | backend `summary.total_count` |
| `perTypeCounts` | `Map<String, int>` | backend `summary.per_type_counts` |
| `perSourceCounts` | `Map<String, int>` | backend `summary.per_source_counts` |
| `sourceStatuses` | `Map<String, String>` | backend `summary.source_statuses` |
| `isPartial` | `bool` | backend `summary.is_partial` |
| `warnings` | `List<String>` | backend `summary.warnings` |

---

### 8. `MusicSearchResultGroup` (Mobile domain model)

Mapped grouped response used by view-model and UI.

| Field | Type | Notes |
|---|---|---|
| `query` | `String` | Echoed backend query |
| `limit` | `int` | Effective backend per-type limit |
| `tracks` | `List<TrackSearchResult>` | Always present |
| `albums` | `List<AlbumSearchResult>` | Always present |
| `artists` | `List<ArtistSearchResult>` | Always present |
| `summary` | `MusicSearchSummary` | Always present |

**Validation**:

- `tracks`, `albums`, and `artists` MUST default to empty lists when absent from payload.
- `query` MUST match submitted query semantics from latest successful request.

---

### 9. `MusicSearchViewState` (Mobile presentation model)

Represents full screen state.

| Field | Type | Notes |
|---|---|---|
| `status` | `SearchScreenStatus` | `idle`, `loading`, `data`, `empty`, `error`, `authRequired` |
| `selectedType` | `SearchResultType` | Active segment |
| `activeQuery` | `String` | Last submitted query |
| `results` | `MusicSearchResultGroup?` | Present in `data` state |
| `errorMessageKey` | `String?` | Localized message selector for error state |

**Rules**:

- `status == data` requires `results != null`.
- `status == empty` means latest completed query has zero items in selected type view and no stale data from previous query.
- Segment switching updates visible list without changing `activeQuery`.

---

## Relationships

```text
MusicSearchQuery (1)
  -> POST /v1/search/music (q)
  -> MusicSearchResultGroup (1)
      ├─ tracks[]  (0..*) TrackSearchResult
      ├─ albums[]  (0..*) AlbumSearchResult
      ├─ artists[] (0..*) ArtistSearchResult
      └─ summary   (1) MusicSearchSummary

Track/Album/ArtistSearchResult (1)
  └─ sources (1..*) ResultAttribution

MusicSearchViewState (1)
  ├─ selectedType (1) SearchResultType
  └─ projects results -> visible typed collection
```

---

## State Transitions

### Query lifecycle

```text
idle
  -> submit non-empty query
  -> loading
     -> success with visible items in selected segment -> data
     -> success with zero visible items in selected segment -> empty
     -> auth/session-expired failure -> authRequired
     -> validation/transient/service failure -> error
```

### Segment switching

```text
data or empty
  -> user selects another segment
  -> selectedType updated
  -> if selected segment has items -> data
  -> if selected segment has no items -> empty
```

### New query while previous request is in-flight

```text
loading(request N)
  -> submit request N+1
  -> loading(request N+1)
  -> ignore late completion from request N
  -> apply only request N+1 result to state
```
