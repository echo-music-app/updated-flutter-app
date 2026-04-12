# Quickstart: Create and List Posts Endpoints

## 1) Implement contracts first (test-first)

1. Add contract tests for:
   - `POST /v1/posts`
   - `GET /v1/posts` (following feed)
   - `GET /v1/me/posts`
   - `GET /v1/user/{userId}/posts`
2. Ensure tests fail before implementation.

## 2) Implement use cases and API adapters

1. Add `CreatePostUseCase` and `ListPostsUseCase`.
2. Add `backend/src/adapters/api/v1/posts.py` with request/response models and route handlers.
3. Add secure URL signer adapters:
   - `backend/src/adapters/security/nginx_secure_link_signer.py` (default)
   - `backend/src/adapters/security/cloudfront_signed_url_signer.py`
4. Include posts router from root `v1` router.

## 3) Implement endpoint behavior

1. `GET /v1/me/posts` → filter by `current_user.id`.
2. `GET /v1/user/{userId}/posts` → filter by provided `userId`.
3. `GET /v1/posts` → resolve accepted friend IDs and filter posts by those IDs.
4. Apply deterministic ordering: `created_at DESC`.
5. Apply stable cursor pagination using ordering keys (`created_at`, `id`).
6. Include `attachments` in each returned `PostResponse` using attachment-type-specific fields.
7. Refactor attachment persistence to single-table inheritance (`attachments` table only) to remove subtype joins.
8. Resolve secure URL provider via hybrid policy (environment default + optional per-attachment override).
9. Use fixed signed URL TTL of `5m` for all providers.
10. Fail closed on signing errors (omit URL metadata; never return raw origin URLs).

## 4) Add integration + unit tests

1. Integration tests for database-backed query behavior for each listing endpoint.
2. Contract tests must assert `attachments` is present and correctly typed in post responses.
3. Integration tests must verify attachment hydration without subtype-table joins after STI migration.
4. Contract and integration tests must verify:
   - default `nginx_secure_link` URL signing
   - CloudFront override URL signing
   - URL expiry behavior at `5m`
   - fail-closed response when signing fails
5. Unit tests for use-case-level validation, query branch selection, and signer-provider resolution.

## 5) Validate quality gates

From `backend/`:

- `uv run pytest tests/contract -k posts`
- `uv run pytest tests/integration -k posts`
- `uv run pytest tests/unit -k posts_use_cases`
- `uv run ruff check .`
- `uv run black --check .`
- `uv run isort --check .`

## 6) Verify API contract artifacts

- Regenerate and review OpenAPI for new endpoints before merge.
- Confirm `/v1/posts` endpoints appear with query parameter constraints.
