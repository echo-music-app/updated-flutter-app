# Research: Mobile Music Search Screen

**Branch**: `010-mobile-search-screen` | **Date**: 2026-03-22

---

## 1. Search Submission Interaction

**Decision**: Trigger search on explicit user submit action from the single query field (keyboard search action or search button), not on every keystroke.

**Rationale**: The feature requires one free-text input and endpoint-driven retrieval. Explicit submission avoids unnecessary request bursts, reduces backend load, and keeps behavior predictable for loading/error states.

**Alternatives considered**:

- Debounced per-keystroke search: rejected for MVP due to increased request volume and more complex stale-response handling.
- Manual "refresh only" behavior after first search: rejected because users expect each entered query to execute directly.

---

## 2. Request Contract to Backend Search Endpoint

**Decision**: Use authenticated `POST /v1/search/music` and always send the submitted query in JSON field `q`. Keep `limit` optional and rely on backend default for initial implementation unless a UI requirement later needs explicit control.

**Rationale**: This matches existing backend contract and the user requirement to send parameter `q` from a single free-text field.

**Alternatives considered**:

- Send query in URL parameters: rejected because endpoint contract expects request body.
- Always send fixed custom `limit`: rejected because no product requirement currently asks for user-controlled limits.

---

## 3. Result-Type Filtering Strategy

**Decision**: Fetch results once per query and apply type filtering client-side via selected segment (`tracks`, `albums`, `artists`) without re-requesting when segment changes.

**Rationale**: Backend response already returns grouped arrays for all three types. Client-side switching makes segmented selection instant and reduces network calls.

**Alternatives considered**:

- Request backend separately per selected segment: rejected because it duplicates requests for the same query and degrades responsiveness.
- Merge all types into one mixed list: rejected because segmented selection is a required interaction.

---

## 4. Domain Object Mapping Shape

**Decision**: Map backend response into typed mobile objects for track, album, and artist results with shared core fields plus type-specific optional fields, then render with dedicated widgets per type.

**Rationale**: The feature explicitly requires mapping to objects and separate widgets for each result type. Typed models reduce presentation branching and keep widget contracts explicit.

**Alternatives considered**:

- Render directly from raw JSON maps: rejected because it weakens type safety and pushes parsing concerns into UI.
- Use one generic result object only: rejected because dedicated widgets and per-type semantics become more fragile.

---

## 5. Error and Authentication Mapping

**Decision**: Translate API failures into typed repository exceptions and map to user-facing states:
- `401` -> auth-required state + session clear path
- `422` -> validation error state for invalid query payloads
- `503` -> service-unavailable style error state
- network/5xx/transient -> retryable error state

**Rationale**: This keeps backend status handling outside UI widgets and aligns with existing app auth flow patterns.

**Alternatives considered**:

- Expose raw backend error payloads in UI: rejected for UX and security reasons.
- Treat all failures as one generic error: rejected because auth-expiry behavior must be distinct.

---

## 6. Stale Response Protection

**Decision**: Guard view-model state updates with an in-flight request token/version so only the latest submitted query can update state.

**Rationale**: Users can submit multiple queries quickly. Without request-version checks, late responses can overwrite newer search results.

**Alternatives considered**:

- Accept last-completed request wins: rejected because it can show outdated results.
- Block new submissions until current request completes: rejected because it harms perceived responsiveness.

---

## 7. Screen State Model

**Decision**: Use a single search screen state model with explicit modes (`idle`, `loading`, `data`, `empty`, `error`, `authRequired`) plus selected result type.

**Rationale**: This matches constitution UX requirements to always handle loading/empty/error and supports deterministic rendering for segmented content.

**Alternatives considered**:

- Separate independent state machines per result type: rejected as unnecessary complexity for grouped one-call responses.
- No `idle` state: rejected because first-load experience should be explicit before any query.

---

## 8. Localization and Accessibility

**Decision**: Add all new search labels/messages/segment titles to ARB files and provide semantics labels for search submission, segmented selection, and retry actions.

**Rationale**: Constitution requires ARB-backed strings and semantic labels for interactive elements.

**Alternatives considered**:

- Hardcoded strings in search widgets: rejected by localization requirements.
- Semantics only for main input: rejected because segmented control and retry are also interactive and must be accessible.

---

## 9. Test-First Coverage Scope

**Decision**: Apply TDD across repository mapping, use case behavior, view-model transitions, screen/widget rendering, and one integration flow for query + segment switching.

**Rationale**: Feature risk spans data mapping correctness and UI state behavior; layered tests provide fast feedback and end-to-end confidence.

**Alternatives considered**:

- Widget tests only: rejected because repository/use-case logic would be under-validated.
- Integration tests only: rejected due to slower feedback and weaker failure isolation.
