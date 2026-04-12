# Data Model: Initialize Backend Project

**Source**: `/docs/domain_model.puml`
**ORM**: SQLAlchemy 2.0 async (mapped_column, DeclarativeBase)
**Database**: PostgreSQL 18

---

## Clarifications

### Session 2026-02-25

- Q: What ID type should be used for all primary keys to avoid B-tree index fragmentation? → A: UUIDv7 — time-ordered (RFC 9562), monotonically increasing; stored as PostgreSQL `uuid` column; generated in the application layer via the `uuid6` Python package (`uuid6.uuid7()`). No `gen_random_uuid()` server default; Python-side `default=uuid6.uuid7` in SQLAlchemy `mapped_column`.
- Q: Which PostgreSQL version should be used? → A: PostgreSQL 18. Podman image: `postgres:18`. Replaces earlier PostgreSQL 15+ target.
- Q: Which container runtime and local dev workflow should be used? → A: Podman Compose (rootless); containers run as current user via `--userns=keep-id` to prevent volume permission issues; repo-root `Makefile` provides `make up` / `make down` / `make logs` targets wrapping `podman compose`. Compose file: `compose.yml` at repo root.

---

## ID Strategy

All primary keys use **UUIDv7** (RFC 9562, time-ordered):

- **Column type**: `UUID` (standard PostgreSQL `uuid` type — unchanged)
- **Generation**: Application-side via `uuid6.uuid7()` (`uuid6` PyPI package)
- **SQLAlchemy**: `mapped_column(UUID, primary_key=True, default=uuid6.uuid7)`
- **Rationale**: Monotonically increasing → inserts always target the rightmost B-tree leaf page; eliminates random-write index/table fragmentation. No `gen_random_uuid()` (UUID v4) used anywhere.

---

## Enumerations

### `UserStatus`
```python
class UserStatus(str, enum.Enum):
    pending  = "pending"
    active   = "active"
    disabled = "disabled"
```

### `Privacy`
```python
class Privacy(str, enum.Enum):
    public   = "Public"   # Artists only
    friends  = "Friends"
    only_me  = "OnlyMe"
```

### `FriendStatus`
```python
class FriendStatus(str, enum.Enum):
    pending  = "pending"
    accepted = "accepted"
    declined = "declined"
```

### `AttachmentType` (discriminator)
```python
class AttachmentType(str, enum.Enum):
    text          = "text"
    artist_post   = "artist_post"
    spotify_link  = "spotify_link"
    soundcloud_link = "soundcloud_link"
    audio_file    = "audio_file"
    video_file    = "video_file"
```

---

## Tables

### `users`

| Column             | Type           | Constraints                                  |
|--------------------|----------------|----------------------------------------------|
| `id`               | UUIDv7         | PK, app-generated (`uuid6.uuid7()`)              |
| `email`            | VARCHAR(255)   | UNIQUE, NOT NULL — **sensitive**             |
| `username`         | VARCHAR(50)    | UNIQUE, NOT NULL — **sensitive**             |
| `password_hash`    | VARCHAR(255)   | NOT NULL                                     |
| `bio`              | VARCHAR(200)   | NULLABLE — UTF-8, max 200 chars — **sensitive** |
| `preferred_genres` | TEXT[]         | NOT NULL, DEFAULT `'{}'`  — **sensitive**    |
| `status`           | UserStatus     | NOT NULL, DEFAULT `pending`                  |
| `is_artist`        | BOOLEAN        | NOT NULL, DEFAULT `false`                    |
| `created_at`       | TIMESTAMPTZ    | NOT NULL, DEFAULT `now()`                    |
| `updated_at`       | TIMESTAMPTZ    | NOT NULL, DEFAULT `now()`, ON UPDATE `now()` |

**Notes**:
- `email`, `username`, `bio`, `preferred_genres` are **sensitive** and MUST be anonymised before logging.
- Signup requires `email` (unique), `username` (unique), `password`.
- `is_artist` flag enables single-table inheritance without a separate Artist table; the `Artist`
  domain entity maps to users where `is_artist = true`.
- `Privacy.public` posts are only permitted for users where `is_artist = true` (enforced in service layer).

**Indexes**: `users(email)`, `users(username)`, `users(status)`

---

### `admin_users`

Separate table; no FK to `users`. Independent authentication flow per constitution § VI.

| Column          | Type         | Constraints                    |
|-----------------|--------------|--------------------------------|
| `id`            | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)|
| `email`         | VARCHAR(255) | UNIQUE, NOT NULL               |
| `password_hash` | VARCHAR(255) | NOT NULL                       |
| `created_at`    | TIMESTAMPTZ  | NOT NULL, DEFAULT `now()`      |

---

### `access_tokens`

Opaque short-lived tokens. Validated server-side on every authenticated request.

| Column       | Type        | Constraints                                            |
|--------------|-------------|--------------------------------------------------------|
| `id`         | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)                       |
| `token_hash` | BYTEA(32)   | UNIQUE, NOT NULL — SHA-256 of raw token; never raw    |
| `user_id`    | UUID        | FK → `users.id` ON DELETE CASCADE, NOT NULL           |
| `expires_at` | TIMESTAMPTZ | NOT NULL — TTL: **15 minutes**                        |
| `revoked_at` | TIMESTAMPTZ | NULLABLE — set synchronously on logout / re-auth      |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`                             |

**Indexes**: `access_tokens(token_hash)` (unique), `access_tokens(user_id)`, `access_tokens(expires_at) WHERE revoked_at IS NULL` (partial, for cleanup worker)

### `refresh_tokens`

Long-lived tokens for issuing new access token pairs without re-authentication.

| Column            | Type        | Constraints                                            |
|-------------------|-------------|--------------------------------------------------------|
| `id`              | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)                       |
| `token_hash`      | BYTEA(32)   | UNIQUE, NOT NULL — SHA-256 of raw token               |
| `user_id`         | UUID        | FK → `users.id` ON DELETE CASCADE, NOT NULL           |
| `access_token_id` | UUID        | FK → `access_tokens.id` ON DELETE SET NULL, NULLABLE |
| `expires_at`      | TIMESTAMPTZ | NOT NULL — TTL: **30 days**                           |
| `rotated_at`      | TIMESTAMPTZ | NULLABLE — set when this token is consumed on refresh |
| `revoked_at`      | TIMESTAMPTZ | NULLABLE — set synchronously on logout                |
| `created_at`      | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`                             |

**Indexes**: `refresh_tokens(token_hash)` (unique), `refresh_tokens(user_id)`

**Token lifecycle**:
- Wire format: `secrets.token_bytes(32)` base64url-encoded; SHA-256 stored in `BYTEA`.
- On logout: `revoked_at = now()` on all tokens for the session — synchronous (constitution § VI).
- On refresh: `rotated_at` set on old refresh token, new pair issued; old access token revoked.
- Cleanup: expired + revoked rows purged by scheduled background job (out of scope for init sprint).

---

### `posts`

| Column       | Type        | Constraints                                        |
|--------------|-------------|----------------------------------------------------|
| `id`         | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)                   |
| `user_id`    | UUID        | FK → `users.id` ON DELETE CASCADE, NOT NULL       |
| `privacy`    | Privacy     | NOT NULL                                           |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`                         |
| `updated_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`, ON UPDATE `now()`      |

**Constraints**: `privacy = 'Public'` only allowed when `users.is_artist = true` (service-layer rule).

---

### `attachments` (base table — joined-table inheritance)

| Column           | Type           | Constraints                                    |
|------------------|----------------|------------------------------------------------|
| `id`             | UUIDv7         | PK, app-generated (`uuid6.uuid7()`)               |
| `attachment_type`| AttachmentType | NOT NULL (polymorphic discriminator)          |
| `post_id`        | UUID           | FK → `posts.id` ON DELETE CASCADE, NULLABLE  |
| `message_id`     | UUID           | FK → `messages.id` ON DELETE CASCADE, NULLABLE|
| `created_at`     | TIMESTAMPTZ    | NOT NULL, DEFAULT `now()`                     |

**Note**: Exactly one of `post_id` / `message_id` MUST be non-null (CHECK constraint).

Private attachments (on friends/private posts or messages) MUST be served via expiring pre-signed URLs (§ VI). This enforcement lives in the attachment service, not the model.

### `attachments_text`

| Column    | Type | Constraints                                      |
|-----------|------|--------------------------------------------------|
| `id`      | UUID | PK, FK → `attachments.id` ON DELETE CASCADE    |
| `content` | TEXT | NOT NULL                                         |

### `attachments_artist_post`

| Column    | Type         | Constraints                                    |
|-----------|--------------|------------------------------------------------|
| `id`      | UUID         | PK, FK → `attachments.id` ON DELETE CASCADE  |
| `content` | TEXT         | NOT NULL                                       |

### `attachments_spotify_link`

| Column     | Type         | Constraints                                   |
|------------|--------------|-----------------------------------------------|
| `id`       | UUID         | PK, FK → `attachments.id` ON DELETE CASCADE |
| `url`      | VARCHAR(512) | NOT NULL                                      |
| `track_id` | VARCHAR(64)  | NULLABLE (Spotify track ID extracted from URL)|

> **Note**: Embedding feasibility to be confirmed for Spotify and SoundCloud (see domain model comment). If embedding is not permitted, these types become link-only.

### `attachments_soundcloud_link`

| Column     | Type         | Constraints                                    |
|------------|--------------|------------------------------------------------|
| `id`       | UUID         | PK, FK → `attachments.id` ON DELETE CASCADE  |
| `url`      | VARCHAR(512) | NOT NULL                                       |
| `track_id` | VARCHAR(64)  | NULLABLE                                       |

### `attachments_audio_file`

| Column        | Type         | Constraints                                   |
|---------------|--------------|-----------------------------------------------|
| `id`          | UUID         | PK, FK → `attachments.id` ON DELETE CASCADE |
| `storage_key` | VARCHAR(512) | NOT NULL (object-store path/key)             |
| `mime_type`   | VARCHAR(64)  | NOT NULL                                      |
| `size_bytes`  | BIGINT       | NOT NULL                                      |

### `attachments_video_file`

| Column        | Type         | Constraints                                   |
|---------------|--------------|-----------------------------------------------|
| `id`          | UUID         | PK, FK → `attachments.id` ON DELETE CASCADE |
| `storage_key` | VARCHAR(512) | NOT NULL                                     |
| `mime_type`   | VARCHAR(64)  | NOT NULL                                      |
| `size_bytes`  | BIGINT       | NOT NULL                                      |

---

### `message_threads`

| Column       | Type        | Constraints                       |
|--------------|-------------|-----------------------------------|
| `id`         | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)  |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`        |

**Note**: Initially 2 participants max (domain model constraint). Enforced in service layer.

### `message_thread_participants` (association table)

| Column      | Type | Constraints                                           |
|-------------|------|-------------------------------------------------------|
| `thread_id` | UUID | FK → `message_threads.id` ON DELETE CASCADE, NOT NULL|
| `user_id`   | UUID | FK → `users.id` ON DELETE CASCADE, NOT NULL          |

PK: `(thread_id, user_id)`

### `messages`

| Column       | Type        | Constraints                                              |
|--------------|-------------|----------------------------------------------------------|
| `id`         | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)                         |
| `thread_id`  | UUID        | FK → `message_threads.id` ON DELETE CASCADE, NOT NULL  |
| `sender_id`  | UUID        | FK → `users.id` ON DELETE SET NULL, NOT NULL           |
| `created_at` | TIMESTAMPTZ | NOT NULL, DEFAULT `now()`                               |

**Constraint**: Sender MUST be a participant of the thread (service-layer rule).
**Constraint**: Users can only message friends (service-layer rule).

---

### `friends`

| Column       | Type         | Constraints                                               |
|--------------|--------------|-----------------------------------------------------------|
| `id`         | UUIDv7       | PK, app-generated (`uuid6.uuid7()`)                          |
| `user1_id`   | UUID         | FK → `users.id` ON DELETE CASCADE, NOT NULL             |
| `user2_id`   | UUID         | FK → `users.id` ON DELETE CASCADE, NOT NULL             |
| `status`     | FriendStatus | NOT NULL, DEFAULT `pending`                              |
| `created_at` | TIMESTAMPTZ  | NOT NULL, DEFAULT `now()`                                |
| `updated_at` | TIMESTAMPTZ  | NOT NULL, DEFAULT `now()`, ON UPDATE `now()`            |

**Constraints**:
- `user1_id < user2_id` enforced via CHECK to prevent duplicate bidirectional rows.
- UNIQUE on `(user1_id, user2_id)`.
- `status = 'declined'` is retained for audit purposes.

**Indexes**: `friends(user1_id)`, `friends(user2_id)`, `friends(user1_id, user2_id)` (unique)

---

## Entity Relationship Summary

```
users ──< posts ──< attachments (polymorphic subtypes)
users >──< message_threads >──< messages ──< attachments
users >──< friends
users ──< auth_tokens
admin_users (independent)
```

## State Transitions

### UserStatus
```
[signup] → pending → active (email verified / admin activation)
                  ↓
               disabled (admin action)
```

### FriendStatus
```
[request] → pending → accepted
                    → declined
```