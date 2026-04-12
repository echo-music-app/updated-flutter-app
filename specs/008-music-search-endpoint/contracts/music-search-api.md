# API Contract: Unified Music Search

## Base

- Prefix: `/v1`
- Auth: Bearer opaque token required
- Content-Type: `application/json`

---

## POST `/v1/search/music`

Unified multi-type music search across Spotify and SoundCloud.

### Request Body

```json
{
  "q": "daft punk",
  "limit": 20
}
```

- `q` (required, string): free-text search term
- `limit` (optional, integer): per-type limit (`1..50`, default `20`)

### Validation

- Reject empty/whitespace-only `q` with clear validation message.
- Accept punctuation and non-Latin characters in `q`.
- Reject out-of-range `limit` values (`<1` or `>50`).

### Response: `200 OK`

```json
{
  "query": "daft punk",
  "limit": 20,
  "tracks": [
    {
      "id": "track:harder-better-faster-stronger:daft-punk",
      "type": "track",
      "display_name": "Harder, Better, Faster, Stronger",
      "primary_creator_name": "Daft Punk",
      "duration_ms": 224000,
      "playable_link": "https://open.spotify.com/track/...",
      "artwork_url": "https://i.scdn.co/image/...",
      "sources": [
        {
          "source": "spotify",
          "source_item_id": "spotify:track:3H3cOQ6LBLSvmcaV7QkZEu",
          "source_url": "https://open.spotify.com/track/3H3cOQ6LBLSvmcaV7QkZEu"
        },
        {
          "source": "soundcloud",
          "source_item_id": "soundcloud:tracks:1234",
          "source_url": "https://soundcloud.com/..."
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
      "soundcloud": 1
    },
    "source_statuses": {
      "spotify": "matched",
      "soundcloud": "matched"
    },
    "is_partial": false,
    "warnings": []
  }
}
```

### Response Behavior

- Full response: both providers return `matched`/`no_matches`, `is_partial=false`.
- Partial response: one provider unavailable, the other responds; `is_partial=true`, warnings populated.
- No-match response: `tracks[]`, `albums[]`, `artists[]` all empty arrays; statuses indicate `no_matches`.

### Error Responses

- `401 Unauthorized` — missing or invalid bearer token
- `422 Unprocessable Entity` — request validation errors (`q`, `limit`)
- `503 Service Unavailable` — both providers unavailable (explicit unavailable outcome)

---

## Unified Item Schema

Each item in `tracks[]`, `albums[]`, `artists[]` includes:

- `id: string` (deterministic normalized ID)
- `type: "track" | "album" | "artist"`
- `display_name: string`
- `primary_creator_name: string | null`
- `duration_ms: integer | null` (track-focused)
- `playable_link: string | null`
- `artwork_url: string | null`
- `sources: ResultAttribution[]` (at least one)
- `relevance_score: number`

`ResultAttribution` fields:

- `source: "spotify" | "soundcloud"`
- `source_item_id: string`
- `source_url: string | null`

---

## Response Summary Schema

- `total_count: integer`
- `per_type_counts: { tracks: int, albums: int, artists: int }`
- `per_source_counts: { spotify: int, soundcloud: int }`
- `source_statuses: { spotify: "matched"|"no_matches"|"unavailable", soundcloud: "matched"|"no_matches"|"unavailable" }`
- `is_partial: boolean`
- `warnings: string[]`

---

## External Provider Contracts (Infrastructure Clients)

### Spotify Client Contract

- Endpoint: `GET https://api.spotify.com/v1/search`
- Auth header: `Authorization: Bearer <spotify_access_token>`
- Required params:
  - `q`: search term
  - `type`: `track,album,artist`
- Optional params:
  - `limit`: requested per-type page size
  - `offset`: pagination offset (default `0`)
  - `market`: ISO-3166-1 alpha-2 market code
- Success mapping:
  - `tracks.items[]` -> `type=track`
  - `albums.items[]` -> `type=album`
  - `artists.items[]` -> `type=artist`
- Error mapping:
  - `401`/`403` -> provider status `unavailable`
  - `429` -> provider status `unavailable` with rate-limit warning
  - `5xx`/network timeout -> provider status `unavailable`

### SoundCloud Client Contract

- Endpoints:
  - `GET https://api.soundcloud.com/tracks`
  - `GET https://api.soundcloud.com/playlists`
  - `GET https://api.soundcloud.com/users`
- Auth header: `Authorization: OAuth <soundcloud_access_token>`
- Common params:
  - `q`: search term
  - `limit`: number of results (`1..200` by provider contract)
  - `linked_partitioning=true`
- Success mapping:
  - `/tracks` `collection[]` -> `type=track`
  - `/playlists` `collection[]` -> `type=album` candidates
  - `/users` `collection[]` -> `type=artist`
- Error mapping:
  - `401` -> provider status `unavailable`
  - `429` -> provider status `unavailable` with throttle warning
  - `5xx`/network timeout -> provider status `unavailable`

### Internal Client Interface Contract

```python
class MusicProviderClient(Protocol):
    async def search_tracks(self, term: str, limit: int) -> list[SourceResultItem]: ...
    async def search_albums(self, term: str, limit: int) -> list[SourceResultItem]: ...
    async def search_artists(self, term: str, limit: int) -> list[SourceResultItem]: ...
```

Provider adapters MUST raise provider-specific exceptions that can be translated into `matched`, `no_matches`, or `unavailable` statuses without leaking raw provider errors to API consumers.
