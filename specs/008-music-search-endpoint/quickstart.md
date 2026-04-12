# Quickstart: Unified Music Search Endpoint

## 1) Add failing contract tests first

1. Create `backend/tests/contract/test_music_search_contract.py`.
2. Add contract tests for:
   - `POST /v1/search/music` success with grouped arrays
   - `POST /v1/search/music` unauthorized request returns `401`
   - validation failure for empty `q`
   - validation failure for out-of-range `limit`
   - partial response when one provider is unavailable
   - service-unavailable outcome when both providers are unavailable
3. Confirm all new tests fail before implementation.

## 2) Define domain and application contracts

1. Add domain models under `backend/src/backend/domain/music_search/`:
   - `entities.py`
   - `exceptions.py`
2. Add application layer contracts under `backend/src/backend/application/music_search/`:
   - `ports.py` for provider client protocols and bulkhead/time-budget interfaces
   - `use_cases.py` for orchestration entry point

## 3) Implement provider clients (infrastructure)

1. Add `backend/src/backend/infrastructure/music_providers/spotify_search_client.py`:
   - app-token retrieval and caching
   - `GET https://api.spotify.com/v1/search` request mapping
   - response normalization to `SourceResultItem`
2. Add `backend/src/backend/infrastructure/music_providers/soundcloud_search_client.py`:
   - client-credentials token retrieval and caching
   - `/tracks`, `/playlists`, `/users` query logic
   - response normalization to `SourceResultItem`
3. Map provider errors/timeouts/rate limits to typed provider exceptions.

## 4) Implement unified use case orchestration

1. In `application/music_search/use_cases.py`, fan out provider requests in parallel.
2. Apply provider-specific bulkheads (semaphores) and timeout budgets.
3. Normalize and merge results by type (`track`, `album`, `artist`).
4. Deduplicate within each type while preserving source attribution.
5. Compute deterministic ordering and summary counts/statuses.
6. Generate partial/unavailable outcomes per FR-012/FR-013.

## 5) Expose the API endpoint

1. Add `backend/src/backend/presentation/api/v1/music_search.py` with:
   - request body model (`q`, `limit`)
   - response DTOs aligned with `contracts/music-search-api.md`
   - dependency wiring for use case + provider clients
2. Register router in `backend/src/backend/presentation/api/v1/__init__.py`.
3. Add new settings to `backend/src/backend/core/config.py`:
   - provider credentials and token URLs
   - request timeouts
   - bulkhead limits
   - optional default Spotify market

## 6) Add integration + unit tests

1. Integration tests in `backend/tests/integration/presentation/api/v1/test_music_search.py`:
   - full success path with mocked providers
   - partial path (one provider timeout/429)
   - both unavailable path
2. Unit tests in `backend/tests/unit/application/music_search/test_use_cases.py`:
   - dedupe key behavior
   - deterministic sorting tie-breakers
   - summary/status generation
3. Unit tests in `backend/tests/unit/infrastructure/music_providers/test_provider_clients.py`:
   - request contract formation
   - provider response mapping
   - provider error translation

## 7) Run quality gates

From `backend/`:

- `uv run pytest tests/contract -k music_search`
- `uv run pytest tests/integration -k music_search`
- `uv run pytest tests/unit -k music_search`
- `uv run ruff check .`
- `uv run black --check .`
- `uv run isort --check .`

## 8) Verify contract integrity

1. Ensure endpoint path, request body schema, and response schema match `contracts/music-search-api.md`.
2. Regenerate and review OpenAPI diff for `/v1/search/music` before merge.
3. Confirm source status values and grouped arrays are always present in examples and tests.
