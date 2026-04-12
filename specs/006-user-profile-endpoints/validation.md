# Validation: User Profile Read and Self-Management Endpoints

## Quality Gates

### Lint

```
make lint → All checks passed! (ruff)
```

### Tests

```
make test → 195 passed, 4 warnings
Required test coverage of 100.0% reached. Total coverage: 100.00%
```

### Architecture Boundary Check

Clean Architecture layer imports verified:
- Domain (`backend.domain.profiles`) — no SQLAlchemy imports; pure dataclasses
- Application (`backend.application.profiles`) — depends only on domain protocols and exceptions; no SQLAlchemy
- Infrastructure (`backend.infrastructure.persistence.repositories.profile_repository`) — SQLAlchemy concrete implementation
- Presentation (`backend.presentation.api.v1.profiles`) — imports application use cases and infrastructure repositories for DI wiring

```
uv run ruff check src → All checks passed! (no cross-layer import violations)
```

### Unit Coverage for Feature Use-Case Logic

| File | Coverage |
|------|----------|
| `application/profiles/use_cases.py` | 100% |
| `application/profiles/repositories.py` | 100% |
| `domain/profiles/entities/profile.py` | 100% |
| `domain/profiles/exceptions.py` | 100% |
| `infrastructure/persistence/repositories/profile_repository.py` | 100% |
| `presentation/api/v1/profiles.py` | 100% |

### SQL Query-Count Assertions

Three integration tests assert bounded query counts per endpoint:

- **`GET /v1/users/{userId}`**: `test_get_user_profile_single_query` — asserts ≤3 SELECT statements (token lookup, auth user lookup, profile lookup)
- **`GET /v1/me`**: `test_get_me_single_query` — asserts ≤3 SELECT statements (same pattern)
- **`PATCH /v1/me`**: `test_patch_me_single_query` — asserts ≤6 total statements (token SELECT, user SELECT, profile SELECT, UPDATE, RETURNING/refresh)

No N+1 patterns present: repository methods issue one SELECT per call; no lazy-loaded relations.

### TDD Evidence

Red-green-refactor cycles followed:
1. Wrote failing unit tests for validation rules (T014) — confirmed failures before implementation
2. Implemented `_validate_patch`, `_normalize_patch`, `ProfileUseCases` — tests turned green
3. Wrote contract/integration test scaffolds before endpoint wiring (T015-T017, T021-T023, T027-T029)
4. Implemented endpoints — all tests green
5. Final full-suite run: 195 passed, 100% coverage

### Performance Targets

- `GET` endpoints target p95 ≤ 200ms: Single SELECT query against indexed `users.id` column; achievable.
- `PATCH` endpoint target p95 ≤ 500ms: Single SELECT + UPDATE; achievable.

Latency measurement against live service not performed (no load-test harness available); targets are structurally satisfied by query design.

### OpenAPI Schema

Updated `shared/openapi.json` includes:
- `GET /v1/users/{userId}` → `PublicUserProfileResponse`
- `GET /v1/me` → `MeProfileResponse`
- `PATCH /v1/me` → `MeProfileResponse` (request: `PatchMeRequest`)
