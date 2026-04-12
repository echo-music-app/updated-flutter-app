# Data Model: Mobile Profile Viewing

**Branch**: `009-mobile-profile-view` | **Date**: 2026-03-20

---

## Entities

### 1. `ProfileRouteTarget` (Mobile domain model)

Represents which profile mode the screen should resolve to.

| Field | Type | Notes |
|---|---|---|
| `mode` | `ProfileMode` | `own` or `other` |
| `targetUserId` | `String?` | Required only when `mode == other`; UUID string |
| `isSelfResolved` | `bool` | True when `/profile/:userId` resolves to own mode because `userId == currentUserId` |

**Validation**:

- `targetUserId` MUST be a valid UUID when present.
- `targetUserId` MUST be `null` in own mode.

---

### 2. `ProfileHeader` (Mobile domain model)

Normalized profile header data rendered in both own and other profile screens.

| Field | Type | Source | Notes |
|---|---|---|---|
| `id` | `String` | `/v1/me` or `/v1/users/{userId}` | Canonical user ID |
| `username` | `String` | same | Primary display identifier |
| `bio` | `String?` | same | Optional |
| `preferredGenres` | `List<String>` | same | Optional; display as chips/list |
| `isArtist` | `bool` | same | Optional display affordance |
| `createdAt` | `DateTime` | same | Profile metadata |
| `imageState` | `ProfileImageState` | local | Always placeholder until backend image support exists |

**Validation**:

- `preferredGenres` empty list is valid.
- `bio` may be null/empty and maps to section empty-state copy.

---

### 3. `ProfilePostSummary` (Mobile domain model)

A profile post item as consumed by profile posts UI.

| Field | Type | Source |
|---|---|---|
| `id` | `String` | `/v1/me/posts` or `/v1/user/{userId}/posts` |
| `userId` | `String` | same |
| `privacy` | `String` | same (`Public`, `Friends`, `OnlyMe`) |
| `attachments` | `List<PostAttachmentSummary>` | same |
| `createdAt` | `DateTime` | same |
| `updatedAt` | `DateTime` | same |

**Validation**:

- Own profile mode accepts all privacy values returned by `/v1/me/posts`.
- Other profile mode must only display backend-returned public-visible results.
- Items are expected in descending `created_at` order.

---

### 4. `ProfilePostsPage` (Mobile domain model)

Container for paginated profile posts response.

| Field | Type | Notes |
|---|---|---|
| `items` | `List<ProfilePostSummary>` | Current page payload |
| `pageSize` | `int` | Echoed from backend contract |
| `count` | `int` | Number of items in current page |
| `nextCursor` | `String?` | Opaque cursor for incremental load-more |

**Validation**:

- `nextCursor == null` means no further pages.
- Cursor value is opaque and must not be interpreted by client.

---

### 5. `ProfileScreenState` (Mobile presentation model)

Composed screen state with section-level isolation.

| Field | Type | Notes |
|---|---|---|
| `headerState` | `LoadState<ProfileHeader>` | `loading`, `data`, `empty`, `error`, `notFound`, `authRequired` |
| `postsState` | `LoadState<List<ProfilePostSummary>>` | `loading`, `data`, `empty`, `error`, `authRequired` |
| `isLoadingMore` | `bool` | True while requesting next posts page |
| `canLoadMore` | `bool` | Derived from `nextCursor != null` |

**Rule**:

- `headerState == data` MUST remain visible even when `postsState == error`.

---

## Relationships

```text
ProfileRouteTarget (1) ───── resolves to ───── (1) ProfileHeader source mode
ProfileHeader (1) ─────────── rendered with ─── (0..*) ProfilePostSummary
ProfilePostsPage (1) ──────── contains ───────── (0..*) ProfilePostSummary
ProfileScreenState (1) ────── aggregates ─────── header + posts states
```

---

## State Transitions

### Route resolution

```text
/profile                -> ProfileRouteTarget(mode=own)
/profile/:userId        -> if userId == currentUserId -> mode=own,isSelfResolved=true
                          else mode=other,targetUserId=userId
```

### Screen lifecycle

```text
enter screen
  -> headerState=loading, postsState=loading
  -> header success + posts success (items>0)      -> header=data, posts=data
  -> header success + posts success (items==0)     -> header=data, posts=empty
  -> header success + posts transient failure      -> header=data, posts=error
  -> header not found                              -> header=notFound, posts=empty
  -> auth/session-expired failure                  -> header=authRequired, posts=authRequired, clear stale profile content, prompt re-authentication
```

### Pagination

```text
posts=data + nextCursor present
  -> user taps load-more
  -> isLoadingMore=true
  -> request next page with cursor
  -> success: append items, update nextCursor
  -> failure: keep already loaded items, expose retry affordance for load-more
```
