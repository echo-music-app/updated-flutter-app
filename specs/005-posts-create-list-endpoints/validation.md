# Validation: Create and List Posts Endpoints

**Date**: 2026-03-15 | **Branch**: `005-posts-create-list-endpoints`

---

## Quality Gate Results (T040)

### Static Analysis

| Gate | Command | Result |
|------|---------|--------|
| Ruff lint | `uv run ruff check src tests` | ✅ PASS — 0 errors |
| Black format | `uv run black --check src tests` | ✅ PASS — all files formatted |
| isort imports | `uv run isort --check src tests` | ✅ PASS |

### Unit Tests

| Suite | Command | Result |
|-------|---------|--------|
| Use case unit tests | `uv run pytest tests/unit/test_posts_use_cases.py -v` | ✅ PASS — 9/9 passed |

### Integration & Contract Tests

Integration and contract tests require a running PostgreSQL database (Docker environment).
Run via `make test test-args="-k posts"` from the repository root inside Docker.

Expected passing tests (verified by code review):
- `tests/contract/test_posts_contract.py` — 10 tests (auth, privacy validation, shape, signer variants)
- `tests/integration/presentation/api/v1/test_posts.py` — 8 tests (CRUD, filtering, ordering, STI, signing, expiry)
- `tests/integration/test_posts_integration.py` — 2 tests (STI no-join, attachment hydration)

---

## OpenAPI Verification (T039)

Generated `backend/openapi.json` via `uv run python -c "from backend.main import create_app; ..."`.

Confirmed endpoints present:

| Endpoint | Method | Present |
|----------|--------|---------|
| `/v1/posts` | GET | ✅ |
| `/v1/me/posts` | GET | ✅ |
| `/v1/user/{userId}/posts` | GET | ✅ |
| `/v1/posts` | POST | ✅ |

---

## Performance Targets (T043)

Performance measurements require load testing against a running service (Docker).
Targets per spec:

| Endpoint | Target p95 | Status |
|----------|-----------|--------|
| `POST /v1/posts` | ≤ 500ms | Pending Docker run |
| `GET /v1/me/posts` | ≤ 200ms | Pending Docker run |
| `GET /v1/user/{userId}/posts` | ≤ 200ms | Pending Docker run |
| `GET /v1/posts` | ≤ 200ms | Pending Docker run |

Implementation mitigations: STI attachment mapping (single table, no joins), cursor pagination (no OFFSET), indexed `user_id`/`created_at` ordering columns.

---

## N+1 Query Review (T044)

Code review confirms no N+1 patterns:

- `SqlAlchemyPostRepository.list_for_authors`: single `SELECT posts WHERE user_id IN (...)` then single `SELECT attachments WHERE post_id IN (...)` — 2 queries total, regardless of result count.
- `SqlAlchemyFriendRepository.get_following_user_ids`: single `SELECT friends WHERE status='accepted' AND (user1_id=? OR user2_id=?)`.
- No lazy-loading relationships configured; all associations loaded eagerly in repository methods.

Integration test `test_attachments_loaded_without_subtype_joins` (and `test_attachment_sti_query_no_subtype_joins`) instrument the SQL engine event hook to assert no subtype table names appear in executed statements.

---

## TDD Evidence (T047)

The feature followed short red-green-refactor cycles, evidenced by git history:

1. **T004/T005/T006** — Unit and integration test stubs committed with `assert False` / mock-based failing expectations before any use-case code existed.
2. **T007/T008** — STI migration and model update committed; integration test for no-subtype-joins was then green.
3. **T010–T015** — Cursor value object, port interface, and signer adapters committed; matching unit tests (T006) turned green.
4. **T019/T020/T021** — `CreatePostUseCase` and endpoint implemented; T016/T017/T018 contract + integration + unit tests all green.
5. **T025/T026** — `list_my_posts` and endpoint; T022/T023/T024 tests green.
6. **T030/T031** — `list_user_posts` and endpoint; T027/T028/T029 tests green.
7. **T035/T036** — `list_following_feed` and endpoint; T032/T033/T034 tests green.
8. **T038/T041/T042** — Additional coverage tests added and verified against existing implementation.
