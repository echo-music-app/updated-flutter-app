# Data Model: Unified Music Search Endpoint

## API-Level Request Model

### `MusicSearchRequest`

- `q: str` (required) — free-text search term (request body field)
- `limit: int = 20` (optional) — per-type result cap (request body field)

Validation:

- `q` must be non-empty after trim (FR-002).
- `q` supports spaces, punctuation, and non-Latin characters (FR-014).
- `limit` range is `1..50`; default `20` (FR-010).

## Core Domain Entities

### `SourceResultItem` (provider-normalized input)

- `source: Literal["spotify", "soundcloud"]`
- `source_item_id: str`
- `type: Literal["track", "album", "artist"]`
- `display_name: str`
- `primary_creator_name: str | None`
- `duration_ms: int | None`
- `playable_link: str | None`
- `artwork_url: str | None`
- `provider_relevance: float | None`

Notes:

- Represents one provider hit after provider-specific parsing.
- Used as input to dedupe and ranking.

### `ResultAttribution`

- `source: Literal["spotify", "soundcloud"]`
- `source_item_id: str`
- `source_url: str | None`

Notes:

- Preserves provenance for deduplicated merged items.
- One unified item can contain multiple attributions.

### `UnifiedResultItem`

- `id: str` (stable deterministic ID for response)
- `type: Literal["track", "album", "artist"]`
- `display_name: str`
- `primary_creator_name: str | None`
- `duration_ms: int | None`
- `playable_link: str | None`
- `artwork_url: str | None`
- `sources: list[ResultAttribution]`
- `relevance_score: float`

Validation:

- `sources` must be non-empty.
- `duration_ms`, when present, must be positive.
- `type` must match the collection where it appears.

### `SourceSearchStatus`

- `source: Literal["spotify", "soundcloud"]`
- `status: Literal["matched", "no_matches", "unavailable"]`
- `count: int`
- `message: str | None`

Notes:

- `message` is populated for unavailable/degraded cases.
- `count` is provider-visible count after normalization.

### `SearchResponseSummary`

- `total_count: int`
- `per_type_counts: dict[str, int]` (`tracks`, `albums`, `artists`)
- `per_source_counts: dict[str, int]` (`spotify`, `soundcloud`)
- `source_statuses: dict[str, Literal["matched", "no_matches", "unavailable"]]`
- `is_partial: bool`
- `warnings: list[str]`

### `UnifiedMusicSearchResponse`

- `query: str`
- `limit: int`
- `tracks: list[UnifiedResultItem]`
- `albums: list[UnifiedResultItem]`
- `artists: list[UnifiedResultItem]`
- `summary: SearchResponseSummary`

Validation:

- `tracks`, `albums`, and `artists` are always present (FR-020).
- Empty/no-match responses return empty arrays, not nulls.

## Relationships

```text
MusicSearchRequest (1)
  ├─> SourceResultItem (0..*) from Spotify
  ├─> SourceResultItem (0..*) from SoundCloud
  └─> UnifiedMusicSearchResponse (1)
       ├─ tracks[]  (0..*) UnifiedResultItem(type=track)
       ├─ albums[]  (0..*) UnifiedResultItem(type=album)
       ├─ artists[] (0..*) UnifiedResultItem(type=artist)
       └─ summary   (1) SearchResponseSummary

UnifiedResultItem (1)
  └─ sources (1..*) ResultAttribution
```

## Deduplication Keys (per type)

- Track key: normalized `display_name` + normalized `primary_creator_name` + duration bucket
- Album key: normalized `display_name` + normalized `primary_creator_name`
- Artist key: normalized `display_name`

## State Transitions

```text
search_requested
  -> provider_calls_started
     -> merged_full            (both providers matched/no_matches, none unavailable)
     -> merged_partial         (at least one provider unavailable, at least one returns data/no_matches)
     -> unavailable            (both providers unavailable)
```

Response behavior:

- `merged_full`: `200 OK`, `summary.is_partial=false`
- `merged_partial`: `200 OK`, `summary.is_partial=true`, warnings populated
- `unavailable`: service-unavailable outcome with explicit source statuses (FR-013)
