# Data Model: User Profile Read and Self-Management Endpoints

## Existing Entity Used

### `User`

- **Source**: `backend/src/backend/infrastructure/persistence/models/user.py`
- **Fields in scope**:
  - `id: UUID`
  - `email: str`
  - `username: str`
  - `bio: str | None`
  - `preferred_genres: list[str]`
  - `status: UserStatus`
  - `is_artist: bool`
  - `created_at: datetime`
  - `updated_at: datetime`

## API-Level Response Projections

### `PublicUserProfile`

- Used by `GET /v1/users/{userId}`
- Fields:
  - `id: UUID`
  - `username: str`
  - `bio: str | None`
  - `preferred_genres: list[str]`
  - `is_artist: bool`
  - `created_at: datetime`

### `MeProfile`

- Used by `GET /v1/me` and response from `PATCH /v1/me`
- Fields:
  - `id: UUID`
  - `email: str`
  - `username: str`
  - `bio: str | None`
  - `preferred_genres: list[str]`
  - `status: str`
  - `is_artist: bool`
  - `created_at: datetime`
  - `updated_at: datetime`

## API-Level Request Models

### `MeProfilePatch`

- Used by `PATCH /v1/me`
- Optional mutable fields only:
  - `username: str | None`
  - `bio: str | None`
  - `preferred_genres: list[str] | None`

## Validation Rules

- `userId` path parameter must be valid UUID for `GET /v1/users/{userId}`.
- Unknown `userId` returns `404`.
- Authenticated user context is mandatory for all endpoints.
- `username`, when provided, must satisfy registration constraints (`3..50`, `^[a-zA-Z0-9_.\-]+$`) and be unique.
- `bio`, when provided, must be at most 200 characters.
- `preferred_genres`, when provided, must contain non-empty strings; duplicates are normalized out before persistence.
- `PATCH /v1/me` must reject payloads with no mutable fields.
- `PATCH /v1/me` must reject attempts to update non-mutable fields (`email`, `status`, `password_hash`, `is_artist`) with `422`.

## State Transitions

### Profile fields in scope

- `current_profile` → `updated_profile` via `PATCH /v1/me` for mutable fields only (`username`, `bio`, `preferred_genres`).
- No lifecycle changes for account status or artist role are introduced by this feature.
