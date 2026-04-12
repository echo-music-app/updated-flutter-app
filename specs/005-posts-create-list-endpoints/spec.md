# Feature Specification: Create and List Posts Endpoints

**Feature Branch**: `005-posts-create-list-endpoints`
**Created**: 2026-03-15
**Status**: Draft
**Input**: User description: "Create backend endpoint for creating and listing posts. Filter options: only own, someone
specific's, people I follow."

## Clarifications

### Session 2026-03-15

- Q: What listing endpoints are required? → A: `GET /v1/posts` (following feed), `GET /v1/me/posts`, and `GET /v1/user/{userId}/posts`.
- Q: Should listing use `scope` query parameter? → A: No, filter mode is encoded by endpoint path.
- Q: Who can create posts? → A: Any authenticated user.
- Q: Which follow relation should be used? → A: Existing accepted friendships/follow relations from the `friends` table.
- Q: Which pagination strategy should listing use? → A: Stable cursor pagination (no `limit`/`offset`).
- Q: What must post list responses include for client rendering? → A: Include post `attachments` in every `PostResponse`.
- Q: How should attachment persistence be mapped to avoid multi-table joins? → A: Use single-table inheritance for attachments.
- Q: How should implementation structure align with architecture governance? → A: Feature implementation MUST follow constitution Clean Architecture layers.
- Q: How should secure attachment URL providers be selected? → A: Use a hybrid strategy with environment default provider and optional per-attachment override; default provider is `nginx_secure_link`.
- Q: How should secure attachment URL expiration be configured across providers? → A: Use a single TTL for all providers set to `5m`.
- Q: What should happen if secure URL signing fails? → A: Fail closed; do not return attachment URL and return safe placeholder metadata only.
- Q: What test discipline is required for implementation quality? → A: Enforce TDD with short red-green-refactor cycles and 100% unit test coverage for feature-touched backend use-case/service logic.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Create Post (Priority: P1)

As an authenticated user, I can create a post with a privacy value so that it appears in future feed queries.

**Why this priority**: Listing endpoints depend on persisted post data; create must exist first.

**Independent Test**: `POST /v1/posts` with valid payload returns `201` and saved post data.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I send a valid `POST /v1/posts` request, **Then** I receive `201` with the
   created post ID, author ID, privacy, and timestamps.
2. **Given** I am authenticated, **When** I send invalid privacy value, **Then** I receive `422` validation error.
3. **Given** I am unauthenticated, **When** I call `POST /v1/posts`, **Then** I receive `401`.

---

### User Story 2 - List My Own Posts (Priority: P1)

As an authenticated user, I can list only my own posts.

**Why this priority**: This is the safest baseline list behavior and needed for profile views.

**Independent Test**: `GET /v1/me/posts` returns only posts where `user_id == current_user.id`.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I call `GET /v1/me/posts`, **Then** response includes only my posts.
2. **Given** I have no posts, **When** I call `GET /v1/me/posts`, **Then** I receive `200` with an empty list.

---

### User Story 3 - List Specific User Posts (Priority: P2)

As an authenticated user, I can list posts for a specific user ID.

**Why this priority**: User profile pages need listing by explicit user target.

**Independent Test**: `GET /v1/user/{userId}/posts` returns only that user's posts.

**Acceptance Scenarios**:

1. **Given** I am authenticated, **When** I call `GET /v1/user/{userId}/posts`, **Then** only that user's posts are returned.
2. **Given** `userId` is malformed UUID, **When** I call endpoint, **Then** I receive `422`.

---

### User Story 4 - List Following Feed (Priority: P2)

As an authenticated user, I can list posts authored by people I follow.

**Why this priority**: Following feed is the core social timeline behavior.

**Independent Test**: `GET /v1/posts` returns posts authored by users connected to me with accepted status.

**Acceptance Scenarios**:

1. **Given** I am authenticated and follow users, **When** I call `GET /v1/posts`, **Then** I receive posts from followed users only.
2. **Given** I follow nobody, **When** I call `GET /v1/posts`, **Then** I receive `200` with an empty list.

---

### Edge Cases

- `userId` path parameter is malformed UUID.
- Pagination cursor is malformed or expired.
- Large post set should be ordered by `created_at` descending and support stable cursor pagination.
- Secure URL signing failure for one or more attachments must not expose raw origin URLs.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: API MUST expose authenticated `POST /v1/posts` to create a post.
- **FR-002**: Create endpoint MUST persist `user_id` from authenticated token, not request body.
- **FR-003**: Create endpoint MUST validate privacy enum against existing post privacy model.
- **FR-004**: API MUST expose authenticated `GET /v1/posts` for following feed posts.
- **FR-005**: API MUST expose authenticated `GET /v1/me/posts` for caller-owned posts.
- **FR-006**: API MUST expose authenticated `GET /v1/user/{userId}/posts` for specific user posts.
- **FR-007**: List endpoints MUST return posts in reverse chronological order.
- **FR-008**: List endpoints MUST use stable cursor pagination, not `limit`/`offset` pagination.
- **FR-009**: Cursor token MUST encode a deterministic position based on ordering keys (`created_at`, `id`).
- **FR-010**: Each returned post MUST include an `attachments` array suitable for client rendering.
- **FR-011**: Attachment persistence MUST use single-table inheritance to avoid subtype-table joins during post listing.
- **FR-012**: Implementation files for this feature MUST follow constitution Clean Architecture layering (`domain`, `application`, `adapters`, `infrastructure`) with inward-only dependencies.
- **FR-013**: API schema for these endpoints MUST be reflected in OpenAPI artifact updates.
- **FR-014**: Attachment URL generation MUST support polymorphic secure-link providers with pluggable implementations.
- **FR-015**: Initial secure attachment URL providers MUST include Amazon CloudFront signed URLs and Nginx secure link module.
- **FR-016**: Provider selection MUST use a hybrid strategy: environment-level default with optional per-attachment override, with `nginx_secure_link` as the default provider.
- **FR-017**: Secure attachment URLs MUST use a single expiration TTL across providers, fixed at `5m`.
- **FR-018**: If secure URL signing fails for an attachment, the API MUST fail closed by omitting the URL and returning safe placeholder metadata only.
- **FR-019**: Implementation MUST follow TDD using short red-green-refactor cycles for all feature changes.
- **FR-020**: Unit tests for all feature-touched backend use-case/service logic MUST maintain 100% coverage.

### Key Entities

- **Post**: Authored content entity with `id`, `user_id`, `privacy`, `created_at`, `updated_at`.
- **Attachment**: Post child entity persisted via single-table inheritance with attachment-type discriminator, nullable type-specific fields, and optional secure URL provider override metadata.
- **PostListEndpoint**: Route-based selection of list source (`/v1/posts`, `/v1/me/posts`, `/v1/user/{userId}/posts`).
- **FriendRelation**: Existing relation source used to derive followed users for `GET /v1/posts`.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: `POST /v1/posts` success path returns `201` in ≤500 ms p95 under local expected load.
- **SC-002**: `GET /v1/me/posts` returns only caller posts with zero false positives in contract tests.
- **SC-003**: `GET /v1/user/{userId}/posts` returns only target user's posts with zero false positives in contract tests.
- **SC-004**: `GET /v1/posts` excludes non-followed users with zero false positives in contract tests.
- **SC-005**: All list endpoint responses include correctly typed `attachments` for each post in contract tests.
- **SC-006**: Attachment loading for post lists avoids subtype-table joins after STI migration in integration tests.
- **SC-007**: Architecture boundary checks for this feature show no cross-layer dependency violations.
- **SC-008**: Contract, integration, and unit tests for this feature pass, and unit test coverage for feature-touched
  backend use-case/service logic is 100%.
- **SC-009**: Secure attachment URL tests verify default `nginx_secure_link` signing and successful switching to CloudFront signed URL generation via provider configuration/override.
- **SC-010**: Secure URL tests verify links generated by both providers expire after `5m` and are rejected after expiry.
- **SC-011**: Failure-path tests verify signing errors return no attachment URL fields and never return unsigned/raw origin URLs.
- **SC-012**: Test execution history for implementation tasks shows failing tests written first, followed by minimal code changes and passing tests in short TDD cycles.

## Assumptions

- Existing auth dependencies already provide `current_user` context for protected endpoints.
- Existing `posts` and `friends` persistence models are the source of truth for post and following data.
- Post body/content fields are out of scope for this request; this feature focuses on endpoint scaffolding and filter
  semantics.
