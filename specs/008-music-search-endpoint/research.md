# Research: Unified Music Search Endpoint

## Decision 1: Keep one unified multi-type endpoint as the MVP API

- **Decision**: Implement authenticated `POST /v1/search/music` as the primary API and return a single payload with grouped arrays: `tracks[]`, `albums[]`, `artists[]`.
- **Rationale**: This directly satisfies FR-001, FR-004, FR-019, and FR-020 while minimizing client orchestration.
- **Alternatives considered**:
  - Separate endpoint per type as the primary API (`/tracks/search`, `/albums/search`, `/artists/search`) — rejected for MVP because it violates the single-request user journey.
  - Multi-endpoint gateway in frontend only — rejected because consistency and resilience logic must live server-side.

## Decision 2: Use Spotify Search API contract as the canonical Spotify source

- **Decision**: Use Spotify Web API `GET https://api.spotify.com/v1/search` with `q=<term>` and `type=track,album,artist`, plus bounded `limit` and configured `market`.
- **Rationale**: One Spotify request can return all three required types in separate buckets, reducing provider call count and simplifying synchronization.
- **Alternatives considered**:
  - Three separate Spotify calls (one per type) — rejected due to extra latency/rate-limit pressure.
  - Track-only Spotify endpoint reuse — rejected because feature scope requires albums and artists.

## Decision 3: Map SoundCloud search contracts per type (`tracks`, `playlists`, `users`)

- **Decision**:
  - Tracks: `GET https://api.soundcloud.com/tracks?q=<term>&limit=<n>&linked_partitioning=true`
  - Albums: `GET https://api.soundcloud.com/playlists?q=<term>&limit=<n>&linked_partitioning=true`, mapped as album candidates
  - Artists: `GET https://api.soundcloud.com/users?q=<term>&limit=<n>&linked_partitioning=true`
- **Rationale**: SoundCloud OpenAPI exposes these search endpoints and response contracts (`collection`, optional `next_href`) and they align to required result types.
- **Alternatives considered**:
  - Skip SoundCloud album mapping — rejected because FR-015 requires album results in scope.
  - Extra per-item `/resolve` calls — rejected for MVP due to call explosion and latency cost.

## Decision 4: Provider auth uses app-level client credentials (not per-user music account linkage)

- **Decision**: Use server-managed app credentials for both providers and cache short-lived access tokens in memory with proactive refresh.
- **Rationale**: Search is a read-only catalog operation and should work for all authenticated Echo users without requiring each user to connect Spotify/SoundCloud accounts.
- **Alternatives considered**:
  - User-delegated provider tokens per request — rejected as unnecessary for catalog search and operationally fragile.
  - Anonymous provider requests — rejected because both providers require authenticated API access.

## Decision 5: Define strict normalized contract for unified results

- **Decision**: Normalize provider payloads into a `UnifiedResultItem` contract with explicit type, source attribution, display metadata, and optional track fields (`duration_ms`, `playable_link`).
- **Rationale**: FR-005, FR-006, and FR-017 require source clarity and standardized cross-provider fields.
- **Alternatives considered**:
  - Return raw provider payloads — rejected because it breaks consistent client consumption and deterministic ranking.
  - Per-provider sub-objects only — rejected because dedupe and ranking become client burdens.

## Decision 6: Deduplicate within result type using metadata-based keys

- **Decision**: Deduplicate cross-source items within each type using normalized keys:
  - track: normalized title + normalized primary creator + duration bucket
  - album: normalized title + normalized primary creator
  - artist: normalized display name
- **Rationale**: FR-009 requires near-identical dedupe while preserving source attribution. Provider IDs alone cannot detect cross-provider duplicates.
- **Alternatives considered**:
  - No dedupe — rejected by FR-009.
  - Strict string equality only — rejected due to minor punctuation/casing variations.

## Decision 7: Deterministic relevance ordering with stable tie-breakers

- **Decision**: Order each type by descending relevance score, then by normalized `display_name`, then by stable identifier for deterministic tie resolution.
- **Rationale**: FR-008 requires deterministic ordering for equivalent relevance.
- **Alternatives considered**:
  - Preserve provider-native ordering only — rejected because merged multi-provider lists can become non-deterministic.
  - Timestamp-based ordering — rejected because search is not recency-first in this feature.

## Decision 8: Enforce provider bulkheads + timeout budgets for controlled degradation

- **Decision**: Apply per-provider bulkhead limits (semaphores) and request timeouts; aggregate with independent failure handling so one provider cannot crash or starve the whole search.
- **Rationale**: FR-021 and FR-022 require isolation under unavailability/throttling and explicit degraded responses.
- **Alternatives considered**:
  - Global shared worker pool only — rejected because one noisy provider can exhaust capacity.
  - Hard fail on first provider error — rejected because FR-012 requires partial results when possible.

## Decision 9: Respect per-type limit contract and keep pagination single-page for MVP

- **Decision**: Support `limit` as per-type cap (default `20`, max `50`) and request a single page from each provider per request; include provider-level counts and statuses in summary.
- **Rationale**: Matches FR-010 and keeps response-time budget controlled for MVP.
- **Alternatives considered**:
  - Multi-page provider fetch and deep merge — rejected as unnecessary complexity for initial release.
  - One global combined limit — rejected because clarified requirements mandate per-type limits.

## Contract References Used

- Spotify Web API Search reference: `https://developer.spotify.com/documentation/web-api/reference/search`
- SoundCloud API guide: `https://developers.soundcloud.com/docs/api/guide`
- SoundCloud OpenAPI specification: `https://developers.soundcloud.com/docs/api/explorer/api.json`
