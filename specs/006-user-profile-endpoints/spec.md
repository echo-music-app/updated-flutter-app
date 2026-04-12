# Feature Specification: User Profile Read and Self-Management Endpoints

**Feature Branch**: `006-user-profile-endpoints`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "create backend endpoints using the same principles as 005 for showing user profiles (`/v1/users/{userId}`) and to manage own profile (`/v1/me`)."

## Clarifications

### Session 2026-03-15

- Q: Which profile endpoints are required? → A: `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me`.
- Q: Should these endpoints require authentication? → A: Yes; all are authenticated, matching feature `005` principles.
- Q: Which fields should be public in `GET /v1/users/{userId}`? → A: `id`, `username`, `bio`, `preferred_genres`, `is_artist`, `created_at`.
- Q: Which additional fields are available on `GET /v1/me`? → A: Include caller-only `email`, `status`, and `updated_at`.
- Q: Which fields can `PATCH /v1/me` mutate? → A: `username`, `bio`, and `preferred_genres` only.
- Q: What are PATCH semantics? → A: Partial update (only provided fields change); at least one mutable field is required.
- Q: How should username updates be validated? → A: Reuse registration rules (`3..50`, `^[a-zA-Z0-9_.\\-]+$`) and enforce uniqueness with `409` on conflict.
- Q: How should implementation quality align with feature `005` principles? → A: Enforce Clean Architecture layering, OpenAPI/contract updates, TDD red-green-refactor cycles, and 100% unit coverage for feature-touched use-case/service logic.
- Q: Can `is_artist` be updated via `PATCH /v1/me`? → A: No; `is_artist` is not mutable via this endpoint.
- Q: Where must the generated OpenAPI artifact be committed for this feature? → A: Commit and review schema updates in `shared/openapi.json`.
- Q: How should architecture boundaries be enforced for this feature? → A: Run and pass backend architecture boundary/import checks before merge.
- Q: How should query performance hygiene be validated for profile endpoints? → A: Review query logs for `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me` to confirm no N+1 patterns.
- Q: Which non-mutable fields require explicit PATCH rejection coverage? → A: `email`, `status`, `password_hash`, and `is_artist`.
- Q: Which commands should be used for quality-gate verification? → A: Use `make lint check` for code style verification and `make test` for test execution.
- Q: What concrete approach should be used for N+1 verification? → A: Use SQLAlchemy statement-count instrumentation in integration tests and record per-endpoint query counts in `validation.md`.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - View Another User Profile (Priority: P1)

As an authenticated user, I can fetch another user profile by ID so profile pages can render stable identity and bio metadata.

**Why this priority**: User profile display is the baseline read path needed by social surfaces.

**Independent Test**: `GET /v1/users/{userId}` returns a public profile payload for a valid target user, and correct errors for malformed/missing targets.

**Acceptance Scenarios**:

1. **Given** I am authenticated and `{userId}` exists, **When** I call `GET /v1/users/{userId}`, **Then** I receive `200` with only public profile fields.
2. **Given** `{userId}` does not exist, **When** I call `GET /v1/users/{userId}`, **Then** I receive `404`.
3. **Given** `{userId}` is malformed UUID, **When** I call `GET /v1/users/{userId}`, **Then** I receive `422`.
4. **Given** I am unauthenticated, **When** I call `GET /v1/users/{userId}`, **Then** I receive `401`.

---

### User Story 2 - View Own Profile (Priority: P1)

As an authenticated user, I can fetch my own profile at `/v1/me` so the app can render my editable account profile state.

**Why this priority**: Own-profile retrieval is required before profile editing and settings workflows.

**Independent Test**: `GET /v1/me` returns only the authenticated user's profile snapshot including caller-only fields.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I call `GET /v1/me`, **Then** I receive `200` with my profile and caller-only fields (`email`, `status`).
2. **Given** I am unauthenticated, **When** I call `GET /v1/me`, **Then** I receive `401`.
3. **Given** my account is disabled, **When** I call `GET /v1/me`, **Then** I receive `403`.

---

### User Story 3 - Manage Own Profile (Priority: P2)

As an authenticated user, I can partially update my editable profile fields using `/v1/me`.

**Why this priority**: Profile management is critical but can follow once read endpoints are in place.

**Independent Test**: `PATCH /v1/me` with valid partial payload persists changes and returns updated profile; invalid/duplicate values produce deterministic errors.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I call `PATCH /v1/me` with valid `bio` and `preferred_genres`, **Then** I receive `200` and persisted updates.
2. **Given** I provide a taken `username`, **When** I call `PATCH /v1/me`, **Then** I receive `409`.
3. **Given** I send no mutable fields, **When** I call `PATCH /v1/me`, **Then** I receive `422`.
4. **Given** I send invalid `username` or oversized `bio`, **When** I call `PATCH /v1/me`, **Then** I receive `422`.

---

### Edge Cases

- `userId` path parameter is malformed UUID.
- `PATCH /v1/me` payload attempts to update non-mutable fields (`email`, `status`, `password_hash`, `is_artist`).
- `PATCH /v1/me` payload contains `preferred_genres` duplicates or blank values.
- Username update conflicts with another existing user.
- Disabled account attempts profile reads/updates (should be blocked by auth dependency with `403`).

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: API MUST expose authenticated `GET /v1/users/{userId}` for public profile retrieval by target user ID.
- **FR-002**: API MUST expose authenticated `GET /v1/me` for caller profile retrieval.
- **FR-003**: API MUST expose authenticated `PATCH /v1/me` for caller profile updates.
- **FR-004**: `GET /v1/users/{userId}` MUST return only public profile fields and MUST NOT expose `email`, auth tokens, password hashes, or internal security metadata.
- **FR-005**: `GET /v1/me` MUST return the authenticated user's profile including caller-only fields (`email`, `status`, `updated_at`).
- **FR-006**: `PATCH /v1/me` MUST support partial updates for `username`, `bio`, and `preferred_genres` only.
- **FR-007**: `PATCH /v1/me` MUST reject requests that omit all mutable fields or attempt to update non-mutable fields (including `is_artist`) with `422`.
- **FR-008**: Username validation MUST match registration rules (`3..50`, regex `^[a-zA-Z0-9_.\\-]+$`).
- **FR-009**: Username uniqueness conflicts MUST return `409 Conflict`.
- **FR-010**: Bio updates MUST enforce maximum length of `200` characters.
- **FR-011**: `preferred_genres` MUST be validated as a list of non-empty strings with duplicate entries removed before persistence.
- **FR-012**: Unknown `userId` MUST return `404`; malformed UUID path input MUST return `422`.
- **FR-013**: Implementation files for this feature MUST follow constitution Clean Architecture layers (`domain`, `application`, `adapters`/`presentation`, `infrastructure`) with inward-only dependencies.
- **FR-014**: API schema for these endpoints MUST be reflected in contract documentation and committed OpenAPI updates in `shared/openapi.json`.
- **FR-015**: Implementation MUST follow TDD using short red-green-refactor cycles for all feature changes.
- **FR-016**: Unit tests for all feature-touched backend use-case/service logic MUST maintain 100% coverage.
- **FR-017**: Feature verification MUST include architecture boundary/import checks to confirm Clean Architecture layer constraints remain intact.
- **FR-018**: Feature verification MUST include SQLAlchemy statement-count instrumentation and query-log review for profile endpoints to confirm no N+1 query patterns.
- **FR-019**: Feature quality-gate execution MUST run through repository Makefile commands (`make lint check` and `make test`) and record outcomes.

### Key Entities

- **User**: Existing persisted account aggregate with profile fields (`id`, `email`, `username`, `bio`, `preferred_genres`, `status`, `is_artist`, timestamps).
- **PublicUserProfile**: Response projection for `GET /v1/users/{userId}` with only public-safe fields.
- **MeProfile**: Response projection for `GET /v1/me` and `PATCH /v1/me` with caller-only fields.
- **MeProfilePatch**: Partial update command object that carries mutable optional fields and validation constraints.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `GET /v1/users/{userId}` returns `200` with only public profile fields for valid users, with zero sensitive-field leaks in contract tests.
- **SC-002**: `GET /v1/me` returns only authenticated caller data with zero cross-user leakage in integration tests.
- **SC-003**: `PATCH /v1/me` persists valid partial updates and reflects updated values in response and subsequent reads.
- **SC-004**: Contract tests verify `404` for unknown user, `422` for malformed UUID/invalid payloads (including non-mutable `email`, `status`, `password_hash`, `is_artist` patch attempts), `409` for username conflicts, and `401` for missing auth.
- **SC-005**: Profile read endpoints satisfy p95 latency ≤200 ms under local expected load; profile update endpoint satisfies p95 latency ≤500 ms.
- **SC-006**: Architecture boundary checks for this feature show no cross-layer dependency violations.
- **SC-007**: Contract, integration, and unit tests for this feature pass, and unit coverage for feature-touched backend use-case/service logic is 100%.
- **SC-008**: Test execution history for implementation tasks shows failing tests written first, followed by minimal implementation changes and passing tests in short TDD cycles.
- **SC-009**: Validation records include per-endpoint SQL statement counts showing no N+1 behavior for `GET /v1/users/{userId}`, `GET /v1/me`, and `PATCH /v1/me`.

## Assumptions

- Existing OAuth opaque-token flow and `get_current_user` dependency remain the source of authentication/authorization behavior.
- Existing `users` table is the source of truth; this feature does not introduce a separate profile table.
- Password/email change flows, avatar/media uploads, and profile privacy controls are out of scope for this feature.
