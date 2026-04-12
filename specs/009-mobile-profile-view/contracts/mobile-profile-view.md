# Contract: Mobile Profile View + Backend Consumption

**Feature**: `009-mobile-profile-view` | **Date**: 2026-03-20
**Type**: REST API consumption contract (Echo backend) + Mobile UI/view-model contract (Flutter)

---

## Backend API Consumption

This feature consumes existing authenticated `/v1` endpoints. No new backend endpoints are introduced in this feature.

### 1) GET `/v1/me`

Retrieve caller profile for own-profile mode.

#### Request

```http
GET /v1/me
Authorization: Bearer <echo_access_token>
Accept: application/json
```

#### Response (`200 OK`) consumed fields

```json
{
  "id": "114fd26c-b6c0-4fd5-8b7a-b737df7a2d31",
  "username": "alice",
  "bio": "Producer and vocalist",
  "preferred_genres": ["house", "ambient"],
  "is_artist": true,
  "created_at": "2026-03-15T16:30:00Z"
}
```

#### Error mapping

| Status | Mobile behavior |
|---|---|
| `401` | Clear session and route to login/auth flow |
| `403` | Show actionable profile access error state |

---

### 2) GET `/v1/users/{userId}`

Retrieve public profile for other-profile mode.

#### Request

```http
GET /v1/users/{userId}
Authorization: Bearer <echo_access_token>
Accept: application/json
```

#### Path parameters

- `userId` (`UUID`, required)

#### Response (`200 OK`) consumed fields

```json
{
  "id": "2f4c18bb-f80e-4222-ae80-9949cacc14a9",
  "username": "artist_jam",
  "bio": "Live sets and deep house",
  "preferred_genres": ["deep house"],
  "is_artist": true,
  "created_at": "2026-03-14T10:12:00Z"
}
```

#### Error mapping

| Status | Mobile behavior |
|---|---|
| `401` | Clear session and route to login/auth flow |
| `404` | Show profile not-found state |
| `422` | Show user-safe invalid-profile/not-found state |

---

### 3) GET `/v1/me/posts`

Retrieve own profile posts in pages.

#### Request

```http
GET /v1/me/posts?page_size=20&cursor=<opaque>
Authorization: Bearer <echo_access_token>
Accept: application/json
```

#### Query parameters

- `page_size` (optional, default `20`, min `1`, max `100`)
- `cursor` (optional, opaque continuation cursor)

#### Response (`200 OK`)

```json
{
  "items": [],
  "count": 0,
  "page_size": 20,
  "next_cursor": null
}
```

---

### 4) GET `/v1/user/{userId}/posts`

Retrieve other-user profile posts in pages.

#### Request

```http
GET /v1/user/{userId}/posts?page_size=20&cursor=<opaque>
Authorization: Bearer <echo_access_token>
Accept: application/json
```

#### Contract notes

- Mobile displays only backend-returned results for this endpoint.
- Privacy filtering is backend responsibility; client does not infer visibility.

#### Error mapping

| Status | Mobile behavior |
|---|---|
| `401` | Clear session and route to login/auth flow |
| `422` | Show invalid-profile/not-found style state |
| `5xx` | Keep header visible when available; show posts section error with retry |

---

## Mobile Route Contract

### Routes

| Route | Mode | Behavior |
|---|---|---|
| `/profile` | own | Uses own-profile endpoint pair (`/v1/me`, `/v1/me/posts`) |
| `/profile/:userId` | other/self-resolved | Uses other-profile endpoint pair unless `userId == currentUserId`, then resolves to own mode |

### Self-route normalization

If navigation targets `/profile/:userId` where `userId` matches current authenticated user, mobile must resolve to own-profile mode and use `/v1/me` behavior.

---

## Mobile UI Contract

### `ProfileViewModel` responsibilities

- Delegate profile mode resolution and loading decisions to domain use cases.
- Orchestrate header and posts loading with independent presentation-state handling.
- Preserve header rendering if posts load fails.
- Support cursor-based load-more append behavior.
- Expose retry actions for header and posts paths.
- Trigger re-authentication prompt path and clear stale profile data on auth/session-expired responses.

### `ProfileScreen` required states

| State area | Required states |
|---|---|
| Header | `loading`, `data`, `empty`, `error`, `not_found`, `auth_required` |
| Posts | `loading`, `data`, `empty`, `error`, `auth_required` |
| Pagination | `idle`, `loading_more`, `append_error` |

### Required visible sections

- Profile image placeholder (always rendered; no backend image dependency)
- Bio section
- Music genres section
- Posts section with incremental paging controls

### Accessibility and localization

- All user-facing strings must come from ARB localization files.
- Retry/load-more controls and profile identity actions must expose semantics labels.

---

## Non-Functional Expectations

- Initial profile content appears quickly with incremental post loading (no full-list blocking).
- Route transitions must not display stale data from previously viewed profile.
- Error copy is user-readable and does not expose raw backend payloads or stack traces.

---

## Implementation Notes (T054 — 2026-03-20)

### Self-route normalization (implemented)

`ResolveProfileTargetUseCase.resolve(userId, currentUserId)` is the single decision point:

- `userId == null || userId.isEmpty` → `ProfileMode.own`, `isSelfResolved: false`
- `userId == currentUserId` → `ProfileMode.own`, `isSelfResolved: true`
- otherwise → `ProfileMode.other`, `targetUserId: userId`

`ProfileViewModel` passes `currentUserId` into the use case at construction time; `app_router.dart` currently passes `null` for `currentUserId` (placeholder until user-session context is threaded through DI).

### Auth-expiry handling (implemented)

On `ProfileAuthException` from either header or posts load:
- Both `headerState` and `postsState` transition to `authRequired`.
- Stale header content is cleared (`header: null`).
- Posts list is cleared (`posts: []`).
- The screen renders the profile error copy (`profileLoadErrorMessage`) for both sections; re-auth routing is the responsibility of the app-level auth guard (`app_router.dart` redirect).

### Pagination behavior (implemented)

- First page loaded on `loadProfile()`; cursor initialized from `ProfilePostsPage.nextCursor`.
- `loadMore()` appends results; existing posts are never replaced.
- `loadMore()` failure resets `isLoadingMore: false` and preserves the already-loaded list; the `ProfilePostsList` widget exposes `hasLoadMoreError` to show a retry affordance.
- `retryPosts()` resets the cursor to `null` and reloads from page 1.
- `canLoadMore` is derived live from `nextCursor != null` after each page response.
