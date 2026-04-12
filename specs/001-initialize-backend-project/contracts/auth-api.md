# API Contract: Authentication & Health

**Prefix**: `/v1/`
**Auth scheme**: Bearer token (opaque, validated server-side)
**Validation layer**: Pydantic v2 models on all request bodies
**Versioning**: All routes under `/v1/`; breaking changes require deprecation period (constitution § III)

---

## Public Endpoints

Endpoints marked `@public_endpoint` do not require authentication.

---

### `GET /v1/health`

Health check. Returns service status.

**Auth**: public (`@public_endpoint`)

**Response 200**:
```json
{
  "status": "ok",
  "version": "0.1.0"
}
```

---

## Auth Endpoints

### `POST /v1/auth/register`

Register a new user account. Returns an access + refresh token pair on success (user is auto-activated for now; `status = pending` until email verification is implemented in a later sprint).

**Auth**: public (`@public_endpoint`)

**Request body** (`application/json`):
```json
{
  "email": "alice@example.com",
  "username": "alice",
  "password": "S3cur3P@ssword!"
}
```

| Field      | Type   | Rules                                         |
|------------|--------|-----------------------------------------------|
| `email`    | string | Valid email format; max 255 chars; unique     |
| `username` | string | 3–50 chars; alphanumeric + `_.-`; unique      |
| `password` | string | Min 8 chars; max 128 chars                    |

**Response 201**:
```json
{
  "access_token": "<opaque-base64url-token>",
  "refresh_token": "<opaque-base64url-token>",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Errors**:
- `400 Bad Request` — validation failure (malformed fields)
- `409 Conflict` — `email` or `username` already taken

---

### `POST /v1/auth/login`

Authenticate with email and password. Returns a new token pair. Previous unexpired tokens for the user are NOT revoked (multiple device support).

**Auth**: public (`@public_endpoint`)

**Request body** (`application/x-www-form-urlencoded`):

> Uses OAuth 2.0 Password Grant form encoding (`grant_type=password`) per FastAPI's `OAuth2PasswordRequestForm`.

| Field        | Type   | Rules    |
|--------------|--------|----------|
| `username`   | string | User's email address |
| `password`   | string | User's password      |
| `grant_type` | string | Must be `"password"` |

**Response 200**:
```json
{
  "access_token": "<opaque-base64url-token>",
  "refresh_token": "<opaque-base64url-token>",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Errors**:
- `400 Bad Request` — missing or malformed form fields
- `401 Unauthorized` — invalid email/password
- `403 Forbidden` — account is `disabled`

---

### `POST /v1/auth/refresh-token`

Exchange a valid refresh token for a new access + refresh token pair. The consumed refresh token is marked `rotated_at = now()` and the old access token is revoked. Rotation is atomic.

**Auth**: public (`@public_endpoint`) — bearer of the refresh token authenticates the call

**Request body** (`application/json`):
```json
{
  "refresh_token": "<opaque-base64url-token>"
}
```

**Response 200**:
```json
{
  "access_token": "<opaque-base64url-token>",
  "refresh_token": "<opaque-base64url-token>",
  "token_type": "bearer",
  "expires_in": 900
}
```

**Errors**:
- `400 Bad Request` — malformed token
- `401 Unauthorized` — token not found, expired, or already rotated/revoked

---

### `POST /v1/auth/logout`

Revoke all active tokens for the authenticated session. Token invalidation is synchronous (constitution § VI).

**Auth**: required (`Authorization: Bearer <access_token>`)

**Request body**: none

**Response 204**: No Content

**Errors**:
- `401 Unauthorized` — missing, invalid, or expired access token

---

## Authenticated Request Validation

For all non-public endpoints:

1. Extract `Authorization: Bearer <token>` header.
2. Look up `access_tokens WHERE token_hash = SHA256(token)`.
3. If not found, expired (`expires_at < now()`), or `revoked_at IS NOT NULL` → `401`.
4. If the associated user has `status = disabled` → `403`.
5. Attach `User` to request context.

---

## Error Response Schema

All error responses follow a consistent envelope:

```json
{
  "detail": "Human-readable description of the error"
}
```

Internal error codes, stack traces, and raw database errors MUST NOT be surfaced to clients (constitution § IV).

---

## Notes

- Sensitive fields (`email`, `username`, `bio`, `preferred_genres`) MUST be anonymised before appearing in server logs (constitution § VI).
- All endpoint schemas are exported via FastAPI's auto-generated OpenAPI spec at `GET /v1/openapi.json`. The generated `shared/openapi.json` MUST be committed and reviewed on API-changing PRs (constitution § III).