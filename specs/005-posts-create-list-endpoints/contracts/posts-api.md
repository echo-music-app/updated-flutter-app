# API Contract: Posts

## Base

- Prefix: `/v1`
- Auth: Bearer opaque token required for all endpoints in this contract
- Content-Type: `application/json`

---

## POST `/v1/posts`

Create a post for the authenticated user.

### Request Body

```json
{
  "privacy": "Public"
}
```

### Validation

- `privacy` required
- `privacy` must be one of: `Public`, `Friends`, `OnlyMe`

### Responses

- `201 Created`

```json
{
  "id": "8fa5fa66-37ed-4aa4-a654-cf80efff2a7c",
  "user_id": "114fd26c-b6c0-4fd5-8b7a-b737df7a2d31",
  "privacy": "Public",
  "attachments": [],
  "created_at": "2026-03-15T16:30:00Z",
  "updated_at": "2026-03-15T16:30:00Z"
}
```

- `401 Unauthorized`
- `422 Unprocessable Entity`

---

## GET `/v1/posts`

List following-feed posts for the authenticated user.

### Query Parameters

- `page_size` (optional, default `20`, min `1`, max `100`)
- `cursor` (optional): opaque continuation token from previous response

### Semantics

- Returns posts authored by users in accepted follow/friend relation with authenticated user.

---

## GET `/v1/me/posts`

List posts authored by the authenticated user.

### Query Parameters

- `page_size` (optional, default `20`, min `1`, max `100`)
- `cursor` (optional): opaque continuation token from previous response

### Semantics

- Returns posts where `user_id == current_user.id`.

---

## GET `/v1/user/{userId}/posts`

List posts authored by a specific user.

### Path Parameters

- `userId` (UUID, required)

### Query Parameters

- `page_size` (optional, default `20`, min `1`, max `100`)
- `cursor` (optional): opaque continuation token from previous response

### Semantics

- Returns posts where `user_id == userId`.

### Responses

- `200 OK`

```json
{
  "items": [
    {
      "id": "8fa5fa66-37ed-4aa4-a654-cf80efff2a7c",
      "user_id": "114fd26c-b6c0-4fd5-8b7a-b737df7a2d31",
      "privacy": "Public",
      "attachments": [
        {
          "id": "af5f459c-65be-49cc-9b46-9df0d8b4d355",
          "type": "spotify_link",
          "url": "https://open.spotify.com/track/abc123",
          "track_id": "abc123",
          "created_at": "2026-03-15T16:25:00Z"
        }
      ],
      "created_at": "2026-03-15T16:30:00Z",
      "updated_at": "2026-03-15T16:30:00Z"
    }
  ],
  "count": 1,
  "page_size": 20,
  "next_cursor": "eyJjcmVhdGVkX2F0IjoiMjAyNi0wMy0xNVQxNjozMDowMFoiLCJpZCI6IjhmYTVmYTY2LTM3ZWQtNGFhNC1hNjU0LWNmODBlZmZmMmE3YyJ9"
}
```

- `401 Unauthorized`
- `422 Unprocessable Entity` for malformed UUID/invalid enum values

---

## Attachment Object (within `PostResponse.attachments`)

- `id` (UUID, required)
- `type` (required): `text | artist_post | spotify_link | soundcloud_link | audio_file | video_file`
- `created_at` (datetime, required)
- Variant fields (optional based on `type`):
  - `content` for `text` and `artist_post`
  - `url` and optional `track_id` for `spotify_link` / `soundcloud_link`
  - `storage_key`, `mime_type`, `size_bytes` for `audio_file` / `video_file`

---

## Non-Functional Guarantees

- Ordering: newest first (`created_at DESC`)
- Stable pagination via cursor (`created_at`, `id`)
- Authenticated-only access per constitution security requirements
