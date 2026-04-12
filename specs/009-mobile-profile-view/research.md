# Research: Mobile Profile Viewing

**Branch**: `009-mobile-profile-view` | **Date**: 2026-03-20

---

## 1. Profile Data Source by Mode

**Decision**: Use mode-specific endpoint pairs:

- Own profile mode: `GET /v1/me` + `GET /v1/me/posts`
- Other profile mode: `GET /v1/users/{userId}` + `GET /v1/user/{userId}/posts`

**Rationale**: Existing backend contracts already separate caller-only profile shape from public profile shape. Using mode-specific endpoints avoids leaking/depending on private fields in other-profile views and simplifies deterministic UI mapping.

**Alternatives considered**:

- Always use `GET /v1/users/{userId}` for every profile: rejected because own profile would lose caller-only guarantees and requires synthetic self-target handling.
- Always use `GET /v1/me`: rejected because it cannot load arbitrary other users.

---

## 2. Self-Route Normalization

**Decision**: When profile navigation targets `userId == currentUserId`, resolve to own-profile mode behavior (`/v1/me` + `/v1/me/posts`).

**Rationale**: This was clarified in spec and prevents duplicated code paths and inconsistent UX between direct own-profile route and self user-id route.

**Alternatives considered**:

- Keep separate behavior for self by `userId`: rejected due duplicate state logic and potential divergence.
- Block navigation with prompt: rejected for unnecessary friction.

---

## 3. Other-User Post Visibility

**Decision**: Other-user profile shows only posts that are publicly visible for that user.

**Rationale**: Clarified in spec. Privacy filtering must be enforced by backend response semantics and never inferred client-side.

**Alternatives considered**:

- Client-side filter from full response: rejected because privacy enforcement must not rely on client trust.
- Include follower-only posts by default: rejected because not specified and higher privacy risk.

---

## 4. Pagination Strategy for Profile Posts

**Decision**: Use existing cursor pagination contract (`page_size`, `cursor`) with initial page load and incremental append behavior.

**Rationale**: Existing posts endpoints provide stable cursor pagination and this matches the clarification that profile posts load in pages with load-more behavior.

**Alternatives considered**:

- Load all posts at once: rejected due performance/memory and slower first render.
- Offset pagination: rejected because current backend contract is cursor-based.

---

## 5. Section-Level State Isolation

**Decision**: Model profile header state separately from posts state so posts failures do not hide successful header content.

**Rationale**: Explicit acceptance scenario requires header to remain visible when post retrieval fails. A single monolithic screen state cannot represent this correctly.

**Alternatives considered**:

- Single screen-wide enum (`loading/data/error`): rejected because it conflates independent failures.
- Entirely separate screens for header and posts: rejected as UX-fragmenting for profile view.

---

## 6. Placeholder Image Behavior

**Decision**: Render a deterministic placeholder avatar for all profiles (no network image dependency) until backend image support exists.

**Rationale**: Backend image data is out of scope. A deterministic placeholder prevents broken image UI and satisfies SC-001.

**Alternatives considered**:

- Empty image container: rejected due weak affordance.
- Static bitmap for all users: accepted as fallback option, but deterministic placeholder with user-derived initials gives better identity cues.

---

## 7. Error and Auth Handling Mapping

**Decision**:

- `401` from profile/posts calls -> clear session and route user through existing auth flow.
- `404` for target profile -> show profile not-found state.
- `422` malformed `userId` route parameter -> treat as not-found style state (user-safe behavior).
- Non-auth transient failures -> show section-specific error with retry.

**Rationale**: Matches existing app routing/auth behavior and keeps errors actionable without exposing backend internals.

**Alternatives considered**:

- Raw status-code rendering: rejected (violates UX consistency and security principles).
- Full-screen fatal error for any posts failure: rejected by acceptance scenario requiring header persistence.

---

## 8. Testing Strategy for TDD Compliance

**Decision**: Apply test-first across three levels:

- Widget tests: profile screen state rendering, placeholder image, posts pagination controls.
- Unit tests: view-model mode resolution, pagination append, state transitions, retry behavior.
- Integration tests: own profile, other profile, and self-route normalization end-to-end navigation behavior.

**Rationale**: Aligns with constitution test discipline and verifies both visual state contracts and orchestration logic.

**Alternatives considered**:

- Widget-only testing: rejected; insufficient for route normalization and repository orchestration.
- Integration-only testing: rejected; slow feedback and weak state-level regression isolation.

---

## 9. Localization and Accessibility Approach

**Decision**: Add all new profile strings to ARB (`mobile/lib/l10n/app_en.arb`) and require semantics labels for profile actions (retry/load-more/profile avatar region).

**Rationale**: Constitution mandates ARB-based localization and accessible interactive elements.

**Alternatives considered**:

- Hardcoded strings in widgets: rejected by constitution.
- Semantics only for primary actions: rejected; profile interactions include retry/load-more and require complete coverage.

---

## 10. Business Logic Placement (Clean Architecture Compliance)

**Decision**: Keep profile mode resolution, auth/not-found decisioning, and paginated posts loading policy in domain use cases (`ResolveProfileTargetUseCase`, `LoadProfileHeaderUseCase`, `LoadProfilePostsPageUseCase`) and keep `ProfileViewModel` as orchestration/presentation-state adapter.

**Rationale**: Constitution Principle VIII requires business logic to reside in use cases/domain entities, not widgets/view-model adapter layers. This also makes route/endpoint decision rules testable without widget dependencies.

**Alternatives considered**:

- Keep mode and loading rules directly in `ProfileViewModel`: rejected due architecture violation and lower test isolation.
- Split behavior between repository and widgets: rejected because it mixes domain policy with infrastructure/presentation concerns.
