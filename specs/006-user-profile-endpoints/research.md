# Research: User Profile Read and Self-Management Endpoints

## Decision 1: Use route-based profile resources

- **Decision**: Implement separate endpoints `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me`.
- **Rationale**: Route-driven semantics are explicit, easy to secure, and align with the established feature `005` approach.
- **Alternatives considered**:
  - Single `/v1/profile` endpoint with mode query parameters — rejected due to ambiguity and weaker contract clarity.

## Decision 2: Separate public and caller profile projections

- **Decision**: Return public-safe fields on `GET /v1/users/{userId}` and caller-only fields (`email`, `status`, `updated_at`) on `GET /v1/me`.
- **Rationale**: Minimizes sensitive data exposure while preserving required self-management context.
- **Alternatives considered**:
  - Single response shape for both endpoints — rejected because it risks leaking private account metadata.

## Decision 3: Restrict mutable fields on `PATCH /v1/me`

- **Decision**: Allow partial updates only for `username`, `bio`, and `preferred_genres`; reject updates to `email`, `status`, `password_hash`, and `is_artist` with `422`.
- **Rationale**: Keeps update scope minimal and consistent with requested feature boundaries.
- **Alternatives considered**:
  - Allow `is_artist` changes in this endpoint — rejected per clarification and to avoid role/state mutation coupling.

## Decision 4: OpenAPI artifact location

- **Decision**: Commit API schema updates to `shared/openapi.json`.
- **Rationale**: Aligns with constitution guidance for cross-concern artifacts.
- **Alternatives considered**:
  - Store OpenAPI only under `backend/openapi.json` — rejected due to constitution mismatch and weaker cross-app discoverability.

## Decision 5: Enforce architecture and query-performance verification

- **Decision**: Add explicit verification steps for architecture boundary checks and SQL query-log N+1 review on profile endpoints.
- **Rationale**: Satisfies constitution quality gates and reduces regression/performance risk.
- **Alternatives considered**:
  - Rely only on tests — rejected because tests alone may not reveal cross-layer import drift or N+1 query patterns.

## Decision 6: Preserve existing backend package namespace

- **Decision**: Implement feature modules under existing repository namespace root `backend/src/backend/...` while preserving Clean Architecture boundaries inside that namespace.
- **Rationale**: Matches current codebase imports/runtime wiring and avoids high-risk repo-wide relocation.
- **Alternatives considered**:
  - Move this feature only to `backend/src/...` — rejected because mixed roots create inconsistent imports and integration risk.
