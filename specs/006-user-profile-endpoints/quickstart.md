# Quickstart: User Profile Read and Self-Management Endpoints

## 1) Write tests first (TDD)

1. Add failing contract tests in `backend/tests/contract/test_profiles_contract.py` for:
   - `GET /v1/users/{userId}`
   - `GET /v1/me`
   - `PATCH /v1/me`
2. Add failing integration tests in `backend/tests/integration/presentation/api/v1/test_profiles.py`.
3. Add failing unit tests in `backend/tests/unit/application/profiles/test_use_cases.py`.

## 2) Implement profile domain/application/infrastructure blocks

1. Define profile entities and exceptions:
   - `backend/src/backend/domain/profiles/entities/profile.py`
   - `backend/src/backend/domain/profiles/exceptions.py`
2. Define repository ports and use-case orchestration:
   - `backend/src/backend/application/profiles/repositories.py`
   - `backend/src/backend/application/profiles/use_cases.py`
3. Implement SQLAlchemy profile repository:
   - `backend/src/backend/infrastructure/persistence/repositories/profile_repository.py`

## 3) Implement API adapter endpoints

1. Add endpoint handlers and request/response models in `backend/src/backend/presentation/api/v1/profiles.py`.
2. Register profile router in `backend/src/backend/presentation/api/v1/__init__.py`.
3. Ensure endpoint behavior:
   - `GET /v1/users/{userId}` returns public-safe projection only.
   - `GET /v1/me` returns caller profile projection.
   - `PATCH /v1/me` updates only `username`, `bio`, and `preferred_genres`.
   - `PATCH /v1/me` rejects non-mutable field updates (`email`, `status`, `password_hash`, `is_artist`).

## 4) Run focused validation suites

From `backend/`:

- `uv run pytest tests/contract/test_profiles_contract.py -v`
- `uv run pytest tests/integration/presentation/api/v1/test_profiles.py -v`
- `uv run pytest tests/unit/application/profiles/test_use_cases.py -v`

## 5) Run quality gates

From repository root:

- `make lint check`
- `make test test-args="-k profiles"`

## 6) Verify architecture boundaries and query hygiene

1. Run backend architecture boundary/import checks used by your CI pipeline and record pass/fail in `specs/006-user-profile-endpoints/validation.md`.
2. Add SQLAlchemy statement-count instrumentation in `backend/tests/integration/presentation/api/v1/test_profiles.py` (e.g., event listener on `before_cursor_execute`) and assert bounded query counts for:
   - `GET /v1/users/{userId}`
   - `GET /v1/me`
   - `PATCH /v1/me`
3. Record per-endpoint statement counts and evidence in `specs/006-user-profile-endpoints/validation.md`.

## 7) Update API contract artifacts

1. Update `specs/006-user-profile-endpoints/contracts/profiles-api.md`.
2. Regenerate OpenAPI and commit to `shared/openapi.json`:

```bash
cd backend
uv run python -c "import json; from pathlib import Path; from backend.main import create_app; Path('../shared/openapi.json').write_text(json.dumps(create_app().openapi(), indent=2) + '\n')"
```
