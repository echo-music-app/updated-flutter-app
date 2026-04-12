# Feature Specification: Unified Music Search Endpoint

**Feature Branch**: `008-music-search-endpoint`  
**Created**: 2026-03-18  
**Status**: Draft  
**Input**: User description: "Create endpoint for searching music based on a single input search term, using spotify and soundcloud APIs to do the actual search, and consolidate the results in a single response"

## Clarifications

### Session 2026-03-18

- Q: Which music result types should the unified search endpoint support? → A: tracks, albums, artists.
- Q: How should the result limit apply across multiple result types? → A: Apply the limit per type (tracks, albums, artists); separate endpoints per entity are acceptable.
- Q: What should be required for MVP endpoint strategy? → A: MVP MUST include a unified multi-type endpoint; split per-entity endpoints are optional.
- Q: How should multi-type results be structured in the response? → A: Return grouped arrays by type (`tracks[]`, `albums[]`, `artists[]`) in one consolidated response.
- Q: What resilience behavior is required when an external music API is unavailable or throttling requests? → A: Use bulkheads to isolate provider failures so the search service does not crash and can continue with controlled degraded responses.

### Session 2026-03-19

- Q: What is the required HTTP contract for unified search? → A: Use authenticated `POST /v1/search/music`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search Once Across Music Sources (Priority: P1)

As a listener using Echo, I can submit one search term and receive one consolidated response containing grouped results for tracks, albums, and artists from Spotify and SoundCloud.

**Why this priority**: This is the core value of the feature. Without a unified response from both music sources, the feature objective is not met.

**Independent Test**: Submit one valid search term and verify that one consolidated response contains grouped results from both music sources whenever both have matches.

**Acceptance Scenarios**:

1. **Given** an authenticated caller and a valid search term, **When** `POST /v1/search/music` is submitted, **Then** the system returns one consolidated response with grouped result arrays for tracks, albums, and artists.
2. **Given** both music sources have matches for the term, **When** the search completes, **Then** the consolidated response includes items from Spotify and SoundCloud in the applicable type arrays.
3. **Given** the term has matches across tracks, albums, and artists, **When** the search completes, **Then** the consolidated response includes all matched result types in their corresponding arrays.
4. **Given** neither source has a match, **When** the search completes, **Then** the consolidated response returns `tracks[]`, `albums[]`, and `artists[]` as empty arrays with a clear "no matches" outcome.

---

### User Story 2 - Understand Result Origin and Relevance (Priority: P2)

As a listener, I can see where each result came from and which type it is so I can compare tracks, albums, and artists in a consistent format.

**Why this priority**: Consolidation is only useful if results are understandable and comparable. Users need clear source attribution and predictable ordering.

**Independent Test**: Run searches with known matches and verify each result includes source attribution, consistent metadata fields, and stable relevance ordering within each type array.

**Acceptance Scenarios**:

1. **Given** a consolidated grouped response, **When** results are displayed, **Then** each item shows its source (Spotify or SoundCloud) and result type (track, album, or artist).
2. **Given** results from multiple sources and types, **When** the response is returned, **Then** all items follow a standardized result shape for core fields.
3. **Given** the same search term is repeated under the same source availability conditions, **When** results are returned, **Then** ordering remains deterministic for equivalent relevance.

---

### User Story 3 - Get Partial Results During Source Outages (Priority: P2)

As a listener, I still receive usable search results if one source is temporarily unavailable.

**Why this priority**: External provider instability should not fully block music discovery when at least one source can still respond.

**Independent Test**: Simulate one source being unavailable and verify the response still returns matches from the available source with an explicit partial-results notice.

**Acceptance Scenarios**:

1. **Given** one source is unavailable, **When** a valid search is submitted, **Then** the system returns results from the available source and marks the response as partial.
2. **Given** one source times out, **When** a valid search is submitted, **Then** the response includes source-specific status explaining incomplete coverage.
3. **Given** both sources are unavailable, **When** a valid search is submitted, **Then** the system returns a clear service-unavailable outcome.
4. **Given** one source is throttling requests, **When** a valid search is submitted, **Then** the system remains available, returns a controlled degraded response, and does not crash.

---

### Edge Cases

- Search term is empty, whitespace-only, or exceeds the allowed length.
- Search term contains punctuation, emojis, accents, or non-Latin characters.
- One source returns no matches while the other returns many matches.
- Both sources return near-identical versions of the same track or album.
- The same name appears across multiple types (for example an artist and album sharing a name).
- One source returns incomplete metadata for otherwise valid results.
- One source responds slowly while the other responds quickly.
- One source continuously returns throttling responses while the other source remains healthy.
- Request is sent without valid authentication.
- `Accept-Language` requests an unsupported locale.
- Per-type limits produce large combined responses (for example 50 track + 50 album + 50 artist results).
- Very broad terms produce more matches than the per-type response limit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST provide an authenticated unified multi-type search endpoint exposed as `POST /v1/search/music` that accepts one free-text search term per request.
- **FR-002**: The system MUST reject empty or whitespace-only search terms with a clear validation message.
- **FR-003**: The system MUST run each valid search term against both Spotify and SoundCloud.
- **FR-004**: The system MUST return one consolidated response containing matched items from all successfully searched sources, grouped by result type.
- **FR-005**: Each returned item MUST include clear source attribution.
- **FR-006**: Each returned item MUST include standardized core metadata: result type, display name, and primary creator name when applicable; duration and playable link MUST be included for track results when available.
- **FR-007**: The response MUST include total result count, per-source result counts, and per-type result counts.
- **FR-008**: The system MUST order results within each type array by relevance to the submitted term and use deterministic ordering for equivalent relevance.
- **FR-009**: The system MUST deduplicate near-identical items within the same result type across sources while preserving attribution to each contributing source.
- **FR-010**: The system MUST support an optional result limit that applies independently to each result type; default limit is 20 and maximum limit is 50 per type.
- **FR-011**: The response MUST include per-source search status values: `matched`, `no_matches`, or `unavailable`.
- **FR-012**: If one source is unavailable, the system MUST return partial results from available sources and include a warning that coverage is incomplete.
- **FR-013**: If both sources are unavailable, the system MUST return a clear service-unavailable outcome.
- **FR-014**: The system MUST support search terms that contain spaces, punctuation, and non-Latin characters.
- **FR-015**: The system MUST return search results for only three in-scope unified types: tracks, albums, and artists.
- **FR-016**: Search operations MUST be read-only and MUST NOT modify user or provider data.
- **FR-017**: Each result item MUST explicitly declare its type as one of: `track`, `album`, or `artist`.
- **FR-018**: This feature release MUST expose only the unified endpoint. If per-entity endpoints are introduced in a future release, each endpoint MUST use the same validation rules and response schema conventions defined for unified search responses.
- **FR-019**: The unified response payload MUST expose separate top-level arrays for each type: `tracks[]`, `albums[]`, and `artists[]`.
- **FR-020**: The unified response payload MUST always include all three top-level arrays (`tracks[]`, `albums[]`, `artists[]`), using empty arrays when a type has no matches.
- **FR-021**: The system MUST implement bulkheads for external provider calls so unavailability or throttling in one provider cannot crash the search service or exhaust resources required by other provider searches.
- **FR-022**: When a provider-specific bulkhead limit is reached, the system MUST fail fast for that provider and continue processing unaffected providers with explicit degraded-response status.
- **FR-023**: The system MUST honor the `Accept-Language` header for locale-sensitive response text (validation messages, degraded-response warnings, and service-unavailable outcomes), and MUST fall back to `en` when the requested locale is unsupported.

### Key Entities *(include if feature involves data)*

- **Search Request**: A single user-submitted free-text term and optional per-type result limit.
- **Source Result Item**: A music match from one source, including source identity, result type (`track`, `album`, or `artist`), and source-native metadata.
- **Unified Result Item**: A normalized result representation used in the consolidated response, including source attribution, result type, and standardized core fields.
- **Search Response Summary**: Top-level response metadata including total count, per-source counts, per-type counts, and per-source search statuses.
- **Type Result Group**: A response collection for one result type (`tracks`, `albums`, or `artists`) containing normalized items of that type only.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: At least 95% of valid searches return a full or partial consolidated response within 500 ms under normal operating conditions at the default per-type limits.
- **SC-002**: For a benchmark set of queries where both sources have known matches, at least 90% of responses include results from both Spotify and SoundCloud.
- **SC-003**: 100% of responses include `tracks[]`, `albums[]`, and `artists[]`; every returned item includes source attribution, result type, and standardized core metadata fields.
- **SC-004**: 100% of empty or whitespace-only search submissions are rejected with a clear, actionable validation message.
- **SC-005**: During simulated single-source outages, at least 99% of valid searches still return partial results from the remaining available source.
- **SC-006**: In stakeholder validation with a predefined set of 50 representative queries spanning track, album, and artist intents, at least 85% of searches place an expected match of the intended type within the top 10 results.
- **SC-007**: During simulated unavailability or sustained throttling from either provider, 100% of search requests return controlled responses (full, partial, or unavailable) without service crashes.

## Assumptions

- The feature scope includes track, album, and artist search results only; playlists, podcast episodes, and user profiles are excluded as top-level response types.
- A "single input search term" means one free-text query string per request (no advanced filters in this feature).
- MVP includes a unified multi-type endpoint; split per-entity endpoints are optional extensions.
- Provider-native resources outside the exposed unified types (for example SoundCloud `/playlists` and `/users`) may be queried internally only when normalized into in-scope `albums` or `artists` results.
- Source credentials, access approvals, and usage quotas for Spotify and SoundCloud are available and managed outside this feature.
- The unified search endpoint is protected and callable only by authenticated clients under the platform's existing auth policy.
- Relevance ranking and deduplication are based on available metadata signals and should prioritize user-perceived match quality over strict source ordering.
