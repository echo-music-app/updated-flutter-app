# UI Contract: Admin UI

## Base

- Application type: Browser-based SPA served from `admin/`
- API base: `/admin/v1`
- Auth: Dedicated admin authentication only; non-admin credentials must be denied
- Message management: Explicitly out of scope and absent from the UI

---

## Route Contract

### Public Routes

- `GET /login`
  - Renders the admin sign-in form
  - Redirects to `/` when an active admin session already exists

### Protected Routes

- `GET /`
  - Dashboard shell with navigation to users, content, and friend relationships

- `GET /users`
  - Searchable user list with moderation context

- `GET /users/:userId`
  - User detail and reversible status-management actions

- `GET /content`
  - Searchable content list with moderation status

- `GET /content/:contentId`
  - Content detail with moderation actions, including permanent deletion

- `GET /friend-relationships`
  - Searchable relationship list

- `GET /friend-relationships/:relationshipId`
  - Relationship detail with corrective and permanent-delete actions

---

## Backend Interaction Contract

The admin UI is expected to consume the following endpoint families under `/admin/v1`:

### Authentication

- `POST /admin/v1/auth/login`
- `GET /admin/v1/auth/session`
- `POST /admin/v1/auth/logout`

### Users

- `GET /admin/v1/users`
- `GET /admin/v1/users/{userId}`
- `PATCH /admin/v1/users/{userId}/status`

### Content

- `GET /admin/v1/content`
- `GET /admin/v1/content/{contentId}`
- `POST /admin/v1/content/{contentId}/actions`
- `DELETE /admin/v1/content/{contentId}`

### Friend Relationships

- `GET /admin/v1/friend-relationships`
- `GET /admin/v1/friend-relationships/{relationshipId}`
- `POST /admin/v1/friend-relationships/{relationshipId}/actions`
- `DELETE /admin/v1/friend-relationships/{relationshipId}`

### Explicitly Forbidden

- No message-view endpoints
- No message-search endpoints
- No message-export endpoints
- No message-delete or restore endpoints

---

## Request/Response Expectations

### Sign-In Request

```json
{
  "email": "admin@example.com",
  "password": "********"
}
```

### Session Response

```json
{
  "admin_id": "7d91184a-bf04-4735-8c0a-d9a8df26d7d0",
  "email": "admin@example.com",
  "display_name": "Ops Admin",
  "status": "active",
  "permission_scope": "broad_admin",
  "authenticated_at": "2026-03-17T18:40:00Z"
}
```

### Authentication Contract Rule

Admin authentication for the UI must:

- use backend-issued opaque tokens or equivalent backend-controlled session credentials
- validate authentication server-side on every protected request
- keep token issuance, rotation, and revocation fully backend-controlled
- treat tokens as opaque on the client

### User and Content Response Privacy Rule

User-facing moderation payloads returned to the admin UI must:

- use managed admin-facing response shapes derived from operational records
- anonymize sensitive fields such as email addresses by default on the backend before serialization
- expose only the fields required for the supported moderation workflow

### User Status Update Request

```json
{
  "status": "suspended",
  "reason": "Repeated policy violations"
}
```

### Content Action Request

```json
{
  "action_type": "remove",
  "reason": "Policy violation"
}
```

### Relationship Action Request

```json
{
  "action_type": "delete_permanently",
  "reason": "Fraud ring cleanup",
  "confirmed": true
}
```

### Mutation Response Minimum Shape

Every successful, denied, or failed admin mutation surfaced to the UI should include or allow lookup of:

```json
{
  "outcome": "success",
  "message": "Relationship permanently deleted",
  "admin_action_id": "0f92ee13-50c6-4512-8c1b-fd8c51049745"
}
```

The referenced `admin_action_id` points to a single persisted `AdminAction` record that stores:

- `entityType`
- `entityId`
- serialized JSON change payload

### Concurrent Mutation Conflict Response

Conflicting stale moderation writes should resolve deterministically and return a conflict response shaped like:

```json
{
  "outcome": "conflict",
  "message": "Target changed by another admin. Refresh and retry.",
  "admin_action_id": "0f92ee13-50c6-4512-8c1b-fd8c51049745"
}
```

---

## UI State Guarantees

Every protected screen must handle:

- loading
- empty
- error
- success/updated state

Every destructive action must provide:

- clear target identification
- reason input
- confirmation step
- human-readable result feedback

## Non-Functional Guarantees

- The SPA must build as static assets with Vite
- Route protection must block non-admin access before protected content renders
- Query invalidation must keep list and detail screens consistent after mutations
- The UI must never display message content, message metadata, or message actions
