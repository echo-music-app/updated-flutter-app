# API Contract: Profiles

## Base

- Prefix: `/v1`
- Auth: Bearer opaque token required for all endpoints in this contract
- Content-Type: `application/json`

---

## GET `/v1/users/{userId}`

Return public profile data for a specific user.

### Path Parameters

- `userId` (UUID, required)

### Response (`200 OK`)

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

### Errors

- `401 Unauthorized`
- `404 Not Found` (unknown `userId`)
- `422 Unprocessable Entity` (malformed UUID)

---

## GET `/v1/me`

Return authenticated caller profile data.

### Response (`200 OK`)

```json
{
  "id": "114fd26c-b6c0-4fd5-8b7a-b737df7a2d31",
  "email": "alice@example.com",
  "username": "alice",
  "bio": "Producer and vocalist",
  "preferred_genres": ["house", "ambient"],
  "status": "active",
  "is_artist": true,
  "created_at": "2026-03-15T16:30:00Z",
  "updated_at": "2026-03-15T17:10:00Z"
}
```

### Errors

- `401 Unauthorized`
- `403 Forbidden` (disabled account)

---

## PATCH `/v1/me`

Partially update mutable fields for the authenticated caller.

### Request Body

```json
{
  "username": "alice_music",
  "bio": "Producer and vocalist",
  "preferred_genres": ["house", "ambient", "afrobeat"]
}
```

### Mutable Fields

- `username` (optional)
- `bio` (optional)
- `preferred_genres` (optional)

At least one mutable field is required.

### Validation

- `username`: `3..50`, regex `^[a-zA-Z0-9_.\-]+$`, unique
- `bio`: max 200 chars
- `preferred_genres`: list of non-empty strings; duplicates normalized out
- Non-mutable fields are rejected: `email`, `status`, `password_hash`, `is_artist`

### Response (`200 OK`)

Returns updated `MeProfile` shape (same as `GET /v1/me`).

### Errors

- `401 Unauthorized`
- `409 Conflict` (username already taken)
- `422 Unprocessable Entity` (empty patch, invalid values, or non-mutable fields)

---

## Non-Functional Guarantees

- `GET` endpoints target p95 latency <= 200ms
- `PATCH` endpoint targets p95 latency <= 500ms
- OpenAPI changes for these endpoints are committed in `shared/openapi.json`
- Architecture boundary checks and query-log N+1 review are required before merge
