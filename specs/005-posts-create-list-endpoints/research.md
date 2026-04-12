# Research: Create and List Posts Endpoints

## Decision 1: Use route-based list subresources

- **Decision**: Implement three listing endpoints: `GET /v1/posts` (following feed), `GET /v1/me/posts` (own posts), and `GET /v1/user/{userId}/posts` (specific user posts).
- **Rationale**: Route-based semantics remove query-parameter ambiguity and produce cleaner, self-descriptive API contracts.
- **Alternatives considered**:
  - Single endpoint with `scope` query parameter — rejected due to coupling multiple behaviors behind one route.
  - Implicit behavior from optional params — rejected due to ambiguity and weaker validation.

## Decision 2: Enforce path-driven targeting rules

- **Decision**: Remove list-mode filter query parameters; use path targets (`/posts`, `/me/posts`, `/user/{userId}/posts`) plus shared pagination query params.
- **Rationale**: Eliminates invalid filter combinations by design and improves testability of endpoint intent.
- **Alternatives considered**:
  - Keep query filters and reject conflicts in validation — rejected due to unnecessary complexity compared to route-based semantics.

## Decision 3: Derive `following` feed from accepted friend relations

- **Decision**: Build followed-user set from existing `friends` table where relation status is accepted and either side matches the current user.
- **Rationale**: Reuses existing social graph model without schema changes.
- **Alternatives considered**:
  - Introduce dedicated follower table — cleaner for asymmetric follows, but out of current scope.
  - Materialized feed table — better at scale, but unnecessary complexity for this slice.

## Decision 4: Include attachments in post responses for client rendering

- **Decision**: Return post metadata plus `attachments` in every `PostResponse`, using a type-discriminated attachment shape aligned to the existing attachment persistence model.
- **Rationale**: Clients need attachment payloads to render posts without extra round-trips; attachment variants already exist in the domain model.
- **Alternatives considered**:
  - Exclude attachments and fetch separately — rejected due to extra client complexity and additional network calls.
  - Add placeholder `content` field in API only — rejected to avoid contract drift from persistence.

## Decision 5: Use single-table inheritance for attachment persistence

- **Decision**: Refactor attachment persistence from joined-table inheritance to single-table inheritance in `attachments`, using `attachment_type` as discriminator and nullable type-specific columns.
- **Rationale**: Post listing with attachments avoids multi-table joins and reduces query complexity/latency for feed endpoints.
- **Alternatives considered**:
  - Keep joined-table inheritance — rejected due to join fan-out for heterogeneous attachment lists.
  - Split attachment types into separate APIs — rejected because it increases client orchestration complexity.

## Decision 6: Stable cursor pagination

- **Decision**: Use cursor-based pagination keyed by `created_at DESC, id DESC`, with an opaque `cursor` token and bounded `page_size`.
- **Rationale**: Cursor pagination is stable under inserts/deletes and avoids duplicate/missing rows common with offset pagination in active feeds.
- **Alternatives considered**:
  - `limit`/`offset` pagination — rejected due to instability under concurrent writes.
  - No pagination initially — rejected due to unpredictable response size.

## Decision 7: Polymorphic secure attachment URL providers

- **Decision**: Generate secure attachment URLs through a polymorphic signer abstraction with two initial providers: `nginx_secure_link` and CloudFront signed URLs.
- **Rationale**: A pluggable provider model supports heterogeneous deployment environments while preserving one API contract for attachment responses.
- **Alternatives considered**:
  - Single hardcoded provider — rejected due to infrastructure lock-in.
  - Exposing unsigned origin URLs — rejected due to security risks for private/friend-only content.

## Decision 8: Provider resolution, expiration, and failure policy

- **Decision**: Use hybrid provider selection (environment default + optional per-attachment override) with `nginx_secure_link` as default, fixed `5m` TTL for all providers, and fail-closed behavior when signing fails.
- **Rationale**: Hybrid selection balances operational simplicity with override flexibility; fixed TTL keeps behavior testable and consistent; fail-closed enforces security-first handling.
- **Alternatives considered**:
  - Provider-specific TTLs — rejected to avoid inconsistent client behavior.
  - Fallback to raw URL on signing errors — rejected because it can leak protected content.
