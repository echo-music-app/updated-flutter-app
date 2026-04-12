# Data Model: Create and List Posts Endpoints

## Existing Entities Used

### `Post`

- **Source**: `backend/src/infrastructure/persistence/models/post.py`
- **Fields in scope**:
  - `id: UUID`
  - `user_id: UUID`
  - `privacy: Privacy` (`Public`, `Friends`, `OnlyMe`)
  - `created_at: datetime`
  - `updated_at: datetime`
- **Notes**:
  - No schema migration required for this feature.
  - Create endpoint writes a new row with authenticated `user_id`.

### `Friend`

- **Source**: `backend/src/infrastructure/persistence/models/friend.py`
- **Fields in scope**:
  - `user1_id: UUID`
  - `user2_id: UUID`
  - `status: FriendStatus` (`pending`, `accepted`, `declined`)
- **Usage**:
  - Following feed endpoint (`GET /v1/posts`) resolves candidate author IDs from accepted relations.

### `Attachment`

- **Source**: `backend/src/infrastructure/persistence/models/attachment.py`
- **Mapping strategy**: Single-table inheritance (STI) in `attachments` table with `attachment_type` discriminator
- **Fields in scope**:
  - `id: UUID`
  - `attachment_type: AttachmentType`
  - `url_provider_override: Literal["nginx_secure_link", "cloudfront"] | None`
  - `post_id: UUID | None`
  - `created_at: datetime`
- **Nullable variant fields in same table**:
  - `text`, `artist_post`: `content: str`
  - `spotify_link`, `soundcloud_link`: `url: str`, `track_id: str | None`
  - `audio_file`, `video_file`: `storage_key: str`, `mime_type: str`, `size_bytes: int`

## API-Level Request Models

### `CreatePostRequest`

- `privacy: Literal["Public", "Friends", "OnlyMe"]`

### `ListPostsQuery`

- `page_size: int = 20` (1..100)
- `cursor: str | None` (opaque continuation token; default `None`)

### `UserPostsPath`

- `userId: UUID` (required path parameter for `GET /v1/user/{userId}/posts`)

## API-Level Response Models

### `PostResponse`

- `id: UUID`
- `user_id: UUID`
- `privacy: str`
- `attachments: list[AttachmentResponse]`
- `created_at: datetime`
- `updated_at: datetime`

### `AttachmentResponse`

- `id: UUID`
- `type: Literal["text", "artist_post", "spotify_link", "soundcloud_link", "audio_file", "video_file"]`
- `created_at: datetime`
- `content: str | None`
- `url: str | None`
- `url_provider: Literal["nginx_secure_link", "cloudfront"] | None`
- `expires_at: datetime | None`
- `track_id: str | None`
- `storage_key: str | None`
- `mime_type: str | None`
- `size_bytes: int | None`

### `PostListResponse`

- `items: list[PostResponse]`
- `count: int`
- `page_size: int`
- `next_cursor: str | None`

## Validation Rules

- `userId` path parameter must be valid UUID for `GET /v1/user/{userId}/posts`.
- `cursor` must be a valid opaque token if provided.
- Authenticated user context is mandatory for both create and list operations.
- Attachment variant fields are validated according to `attachment_type` while unused variant fields remain null.
- `url_provider_override`, when present, must be one of `nginx_secure_link` or `cloudfront`; otherwise environment default provider is used.
- Signed attachment URLs must use a fixed `5m` expiry regardless of provider.
- On signing failure, API omits attachment URL data (fail-closed) and must not return raw origin URLs.

## State Transitions

### Post lifecycle (in scope)

- `non-existent` → `created` via `POST /v1/posts`

No update/delete transitions are introduced by this feature.
