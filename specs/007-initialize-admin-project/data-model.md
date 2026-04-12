# Data Model: Initialize Admin UI Project

> This feature initializes a browser-based admin application. There are no new database tables in the UI project itself.
> This document captures the frontend domain models, view-state contracts, and configuration artifacts that shape the
> admin workspace.

## Configuration Artifacts

### `admin/package.json`

The Node package manifest for the admin SPA.

| Field          | Value                                                              |
|----------------|--------------------------------------------------------------------|
| `name`         | `@echo/admin`                                                      |
| `private`      | `true`                                                             |
| `type`         | `module`                                                           |
| `engines.node` | `24.x`                                                             |
| `scripts`      | `dev`, `build`, `preview`, `lint`, `typecheck`, `test`, `test:e2e` |

### `admin/biome.json`

The Biome configuration for JavaScript/TypeScript linting and formatting.

| Field                             | Value                              |
|-----------------------------------|------------------------------------|
| `formatter.enabled`               | `true`                             |
| `linter.enabled`                  | `true`                             |
| `javascript.formatter.quoteStyle` | project-defined                    |
| `files.includes`                  | `src/**`, `tests/**`, config files |

### `admin/.env`

Runtime configuration exposed through `VITE_*` variables.

| Variable            | Required | Description                                                      |
|---------------------|----------|------------------------------------------------------------------|
| `VITE_API_BASE_URL` | Yes      | Base URL for backend REST requests, e.g. `http://localhost:8000` |
| `VITE_APP_NAME`     | Yes      | Display name for the admin UI shell                              |

## Core Frontend Entities

### `AdminSession`

Represents the authenticated browser session for the current admin.

| Field             | Type                     | Required | Notes                                            |
|-------------------|--------------------------|----------|--------------------------------------------------|
| `adminId`         | `string`                 | Yes      | Stable admin account identifier                  |
| `email`           | `string`                 | Yes      | Internal contact/login identifier                |
| `displayName`     | `string`                 | Yes      | Name shown in the app shell                      |
| `status`          | `'active' \| 'disabled'` | Yes      | Disabled sessions force logout and guard failure |
| `permissionScope` | `'full_admin'`           | Yes      | Initial single admin scope per spec              |
| `authenticatedAt` | `string`                 | Yes      | ISO timestamp for session bootstrap              |

**State transitions**

| From            | Event                             | To                |
|-----------------|-----------------------------------|-------------------|
| `unknown`       | Session bootstrap succeeds        | `authenticated`   |
| `unknown`       | Session bootstrap denied          | `unauthenticated` |
| `authenticated` | Session expires or admin disabled | `expired`         |
| `expired`       | Re-authentication succeeds        | `authenticated`   |

### `ManagedUserSummary`

List-row representation for admin moderation views, derived from operational user records.

| Field       | Type                                      | Required | Notes                                 |
|-------------|-------------------------------------------|----------|---------------------------------------|
| `id`        | `string`                                  | Yes      | User identifier                       |
| `username`  | `string`                                  | Yes      | Primary searchable handle             |
| `email`     | `string`                                  | Yes      | Anonymized or masked by the backend by default |
| `status`    | `'active' \| 'restricted' \| 'suspended'` | Yes      | Current moderation state              |
| `createdAt` | `string`                                  | Yes      | ISO timestamp                         |
| `flagCount` | `number`                                  | No       | Aggregate moderation signal           |

### `ManagedUserDetail`

Expanded admin-facing moderation view derived from an operational user record.

| Field                   | Type                 | Required | Notes                                  |
|-------------------------|----------------------|----------|----------------------------------------|
| `summary`               | `ManagedUserSummary` | Yes      | Base profile data from managed admin-facing projection |
| `bio`                   | `string \| null`     | No       | User-entered profile field             |
| `preferredGenres`       | `string[]`           | Yes      | Existing domain field                  |
| `moderationHistory`     | `AdminAction[]`      | Yes      | Most recent audit/action records first |
| `ownedContentIds`       | `string[]`           | Yes      | For navigation to content reviews      |
| `friendRelationshipIds` | `string[]`           | Yes      | For navigation to relationship reviews |

### `UserModerationRequest`

Client-side request payload for a status-changing action. This is not a separately persisted table; persisted history is
captured via `AdminAction`.

| Field          | Type                                      | Required | Notes                                         |
|----------------|-------------------------------------------|----------|-----------------------------------------------|
| `targetStatus` | `'restricted' \| 'suspended' \| 'active'` | Yes      | User accounts are reversible-only             |
| `reason`       | `string`                                  | Yes      | Required moderation justification             |
| `submittedBy`  | `string`                                  | No       | Populated from current session/audit response |
| `submittedAt`  | `string`                                  | No       | ISO timestamp                                 |

**Validation**

- `reason` must be non-empty after trimming
- permanent deletion is invalid for user accounts

### `ManagedContentItem`

Reviewable managed admin-facing content projection exposed in the admin UI.

| Field         | Type                                  | Required | Notes                                |
|---------------|---------------------------------------|----------|--------------------------------------|
| `id`          | `string`                              | Yes      | Content identifier                   |
| `ownerUserId` | `string`                              | Yes      | Related user                         |
| `status`      | `'visible' \| 'removed' \| 'flagged'` | Yes      | Current moderation state             |
| `contentType` | `string`                              | Yes      | E.g. post, comment, media attachment |
| `previewText` | `string \| null`                      | No       | Safe preview shown in lists          |
| `createdAt`   | `string`                              | Yes      | ISO timestamp                        |

### `ContentModerationRequest`

Client-side request payload for content moderation. This is not a separately persisted table; persisted history is
captured via `AdminAction`.

| Field        | Type                                            | Required | Notes                                       |
|--------------|-------------------------------------------------|----------|---------------------------------------------|
| `actionType` | `'remove' \| 'restore' \| 'delete_permanently'` | Yes      | Permanent deletion allowed for content      |
| `reason`     | `string`                                        | Yes      | Required for all mutations                  |
| `confirmed`  | `boolean`                                       | Yes      | Explicit confirmation for destructive flows |

**Validation**

- `reason` must be non-empty
- `delete_permanently` requires confirmation acknowledgement

### `FriendRelationshipRecord`

| Field       | Type                                              | Required | Notes                      |
|-------------|---------------------------------------------------|----------|----------------------------|
| `id`        | `string`                                          | Yes      | Relationship identifier    |
| `userAId`   | `string`                                          | Yes      | First participant          |
| `userBId`   | `string`                                          | Yes      | Second participant         |
| `status`    | `'pending' \| 'active' \| 'blocked' \| 'removed'` | Yes      | Current relationship state |
| `createdAt` | `string`                                          | Yes      | ISO timestamp              |
| `updatedAt` | `string`                                          | Yes      | ISO timestamp              |

**Operational source-of-truth rule**

- `ManagedUserSummary`, `ManagedUserDetail`, and `ManagedContentItem` are admin-facing projections over the existing operational database records
- the operational database remains the source of truth for user and content state
- managed admin-facing entities may be returned by the backend without becoming separate source-of-truth persistence entities
- sensitive fields such as email addresses are anonymized by the backend by default before reaching the UI

### `RelationshipModerationRequest`

Client-side request payload for relationship moderation. This is not a separately persisted table; persisted history is
captured via `AdminAction`.

| Field        | Type                                            | Required | Notes                             |
|--------------|-------------------------------------------------|----------|-----------------------------------|
| `actionType` | `'remove' \| 'restore' \| 'delete_permanently'` | Yes      | Permanent deletion allowed        |
| `reason`     | `string`                                        | Yes      | Required moderation justification |
| `confirmed`  | `boolean`                                       | Yes      | Needed for destructive actions    |

## Audit and Feedback Models

### `AdminAction`

Immutable audit/action record returned by backend-side admin operations and backed by a single persisted entry.

| Field           | Type                                                                                | Required | Notes                                                                             |
|-----------------|-------------------------------------------------------------------------------------|----------|-----------------------------------------------------------------------------------|
| `id`            | `string`                                                                            | Yes      | Audit event identifier                                                            |
| `occurredAt`    | `string`                                                                            | Yes      | ISO timestamp                                                                     |
| `actorAdminId`  | `string`                                                                            | Yes      | Acting admin                                                                      |
| `entityType`    | `'user' \| 'content' \| 'friend_relationship' \| 'auth' \| 'message_access_denial'` | Yes      | In-scope entity types                                                             |
| `entityId`      | `string \| null`                                                                    | No       | Nullable for sign-in denials before subject resolution                            |
| `operationName` | `string`                                                                            | Yes      | Operation performed                                                               |
| `outcome`       | `'success' \| 'denied' \| 'failed'`                                                 | Yes      | Required by spec                                                                  |
| `changePayload` | `Record<string, unknown>`                                                           | Yes      | Serialized JSON change payload; non-mutating operations use explicit empty object |

**Persistence rule**

- `AdminAction` is the sole persisted audit/action record for this feature
- no separate action tables are introduced
- no separate change-detail tables are introduced
- entity linkage uses `entityType` + `entityId`

### `ActionFeedback`

User-visible success/error feedback after a mutation.

| Field           | Type                                | Required | Notes                                                        |
|-----------------|-------------------------------------|----------|--------------------------------------------------------------|
| `variant`       | `'success' \| 'error' \| 'warning'` | Yes      | Toast/banner presentation                                    |
| `title`         | `string`                            | Yes      | Short summary                                                |
| `description`   | `string`                            | No       | Human-readable details                                       |
| `adminActionId` | `string \| null`                    | No       | Shown when backend returns the persisted audit/action record |

## Search and Navigation Models

### `AdminSearchFilters`

Shared table/filter state for user, content, and relationship list screens.

| Field           | Type              | Required | Notes                       |
|-----------------|-------------------|----------|-----------------------------|
| `query`         | `string`          | No       | Free-text search term       |
| `status`        | `string[]`        | No       | Multi-select status filter  |
| `page`          | `number`          | Yes      | 1-based pagination          |
| `pageSize`      | `number`          | Yes      | Table page size             |
| `sortBy`        | `string`          | No       | Backend-aligned sort column |
| `sortDirection` | `'asc' \| 'desc'` | No       | Sort direction              |

**Validation**

- `page >= 1`
- `pageSize` limited to approved table sizes
- unknown filters are dropped before request submission

### `AdminRouteDefinition`

Describes navigable screens in the SPA.

| Route                                   | Guarded | Purpose                        |
|-----------------------------------------|---------|--------------------------------|
| `/login`                                | No      | Admin-only sign-in             |
| `/`                                     | Yes     | Dashboard / landing screen     |
| `/users`                                | Yes     | User moderation list           |
| `/users/:userId`                        | Yes     | User moderation detail         |
| `/content`                              | Yes     | Content moderation list        |
| `/content/:contentId`                   | Yes     | Content moderation detail      |
| `/friend-relationships`                 | Yes     | Relationship moderation list   |
| `/friend-relationships/:relationshipId` | Yes     | Relationship moderation detail |

**Explicit exclusion**

- No message routes
- No message search/export/delete/restore actions

## Directory Contract

```text
admin/
├── src/app/                  # Entry point, providers, router
├── src/core/                 # Env, HTTP, route guards, shared infra
├── src/features/auth/        # Dedicated admin auth flow
├── src/features/users/       # User moderation views and actions
├── src/features/content/     # Content moderation views and actions
├── src/features/friend-relationships/
├── src/shared/ui/            # shadcn/ui primitives
├── tests/unit/
├── tests/component/
└── tests/e2e/
```
