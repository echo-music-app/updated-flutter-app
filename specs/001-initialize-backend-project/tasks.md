# Tasks: Initialize Backend Project

**Input**: Design documents from `/specs/001-initialize-backend-project/`
**Prerequisites**: plan.md ✅, data-model.md ✅, contracts/auth-api.md ✅, research.md ✅, quickstart.md ✅
**Note**: No spec.md present; user stories are derived from `contracts/auth-api.md` and the plan's scope ("auth + health
only").

**Tests**: Included — constitution § II mandates test-first with 100% unit coverage and three-tier (contract /
integration / unit) test structure.

**Organization**: Tasks grouped by endpoint-derived user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no blocking dependencies)
- **[Story]**: Which user story this task belongs to (US1–US5)
- All paths are relative to repo root

---

## Phase 1: Setup (Repo Infrastructure)

**Purpose**: Local dev environment and uv project initialisation. Must precede all code tasks.

- [x] T001 Create `compose.yml` at repo root: Podman Compose service `postgres` using `postgres:18`, named volume
  `postgres_data`, env vars `POSTGRES_USER`, `POSTGRES_PASSWORD`, `POSTGRES_DB`, `userns_mode: keep-id` (current-user
  UID mapping), expose port 5432
- [x] T002 [P] Create `Makefile` at repo root with targets: `up` (`podman compose up -d`), `down` (
  `podman compose down`), `logs` (`podman compose logs -f`); include `.PHONY: up down logs`
- [x] T003 Initialise uv sub-project: run `uv init backend --package` from repo root, then inside `backend/` run
  `uv python pin 3.13` to create `backend/pyproject.toml` and `backend/.python-version`
- [x] T004 Add runtime dependencies inside `backend/`:
  `uv add "fastapi[standard]" "sqlalchemy[asyncio]" asyncpg alembic "pydantic-settings" uuid6 python-multipart`
- [x] T005 Add dev dependencies inside `backend/`:
  `uv add --dev pytest pytest-asyncio anyio httpx pytest-cov black ruff isort mypy "sqlalchemy[mypy]"`
- [x] T006 Configure `backend/pyproject.toml` tool sections: `[tool.black]` (line-length=100), `[tool.ruff.lint]` (
  select=["E","F","I","UP"]), `[tool.isort]` (profile="black"), `[tool.pytest.ini_options]` (asyncio_mode="auto",
  testpaths=["tests"]), `[tool.coverage.report]` (fail_under=100), `[tool.uv.scripts]` (dev="uvicorn src.main:app
  --reload --port 8000", test="pytest --cov=src", lint="ruff check src tests", format="bash -c 'black src tests && isort
  src tests'", migrate="alembic upgrade head")
- [x] T007 [P] Create `backend/.env.example` with: `DATABASE_URL=postgresql+asyncpg://echo:echo@localhost:5432/echo`,
  `SECRET_KEY=change-me-in-production`, `DEBUG=true`, `ACCESS_TOKEN_TTL_SECONDS=900`, `REFRESH_TOKEN_TTL_DAYS=30`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure all user story phases depend on — ORM models, Alembic migration, app factory, auth
middleware.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [x] T008 Create all package `__init__.py` files to establish the src-layout: `backend/src/__init__.py`,
  `backend/src/core/__init__.py`, `backend/src/models/__init__.py`, `backend/src/services/__init__.py`,
  `backend/src/api/__init__.py`, `backend/src/api/v1/__init__.py` (all empty)
- [x] T009 [P] Implement `Settings(BaseSettings)` in `backend/src/core/config.py`: fields `database_url: PostgresDsn`,
  `secret_key: SecretStr`, `debug: bool = False`, `access_token_ttl_seconds: int = 900`,
  `refresh_token_ttl_days: int = 30`, `api_v1_prefix: str = "/v1"`;
  `SettingsConfigDict(env_file=".env", extra="ignore")`; `field_validator("database_url")` normalising `postgres://` →
  `postgresql+asyncpg://`; `@lru_cache get_settings()` factory
- [x] T010 [P] Create `@public_endpoint` marker decorator in `backend/src/core/decorators.py`: sets attribute
  `endpoint.__public__ = True` on the decorated function so that `get_current_user` can detect and skip auth for public
  routes
- [x] T011 [P] Implement token and password utilities in `backend/src/core/security.py`:
  `generate_token() -> tuple[str, bytes]` returns (base64url-encoded raw token string, SHA-256 bytes);
  `hash_token(raw: str) -> bytes` returns SHA-256; `hash_password(plain: str) -> str` and
  `verify_password(plain: str, hashed: str) -> bool` using `passlib[bcrypt]` (add `uv add "passlib[bcrypt]"`)
- [x] T012 Implement `AsyncEngine` + `async_sessionmaker` + `get_db_session` async generator dependency in
  `backend/src/core/database.py`; read `DATABASE_URL` from `get_settings()`; configure `pool_pre_ping=True`,
  `pool_size=10`, `max_overflow=20`, `expire_on_commit=False`; `get_db_session` yields `AsyncSession` and commits on
  success / rolls back on exception
- [x] T013 Create `Base(DeclarativeBase)` + `TimestampMixin` in `backend/src/models/base.py`; `Base` defines
  `id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid6.uuid7)` as the standard PK
  pattern; `TimestampMixin` adds `created_at: Mapped[datetime]` and `updated_at: Mapped[datetime]` as TIMESTAMPTZ with
  `server_default=func.now()` and `onupdate=func.now()`
- [x] T014 [P] Implement `UserStatus(str, Enum)` + `User` ORM model + `AdminUser` ORM model in
  `backend/src/models/user.py`; `User` uses `Base` + `TimestampMixin`; columns: id (UUIDv7), email VARCHAR(255) UNIQUE
  NOT NULL, username VARCHAR(50) UNIQUE NOT NULL, password_hash VARCHAR(255) NOT NULL, bio VARCHAR(200) NULLABLE,
  preferred_genres `ARRAY(Text)` NOT NULL default `{}`, status `UserStatus` NOT NULL default `pending`, is_artist
  BOOLEAN NOT NULL default False; indexes on email, username, status; `AdminUser` separate table (no FK to users): id,
  email, password_hash, created_at
- [x] T015 [P] Implement `FriendStatus(str, Enum)` + `Friend` ORM model in `backend/src/models/friend.py`; columns per
  data-model.md; `CheckConstraint("user1_id < user2_id", name="ck_friends_ordered")`,
  `UniqueConstraint("user1_id", "user2_id")`; indexes on user1_id and user2_id; both FKs reference `users.id` ON DELETE
  CASCADE
- [x] T016 [P] Implement `Privacy(str, Enum)` + `Post` ORM model in `backend/src/models/post.py`; columns: id (UUIDv7),
  user_id FK→users.id CASCADE NOT NULL, privacy `Privacy` NOT NULL, created_at, updated_at; no application business
  logic in the model
- [x] T017 [P] Implement `AttachmentType(str, Enum)` + `Attachment` base + six child tables in
  `backend/src/models/attachment.py` using joined-table polymorphism (
  `__mapper_args__ = {"polymorphic_on": attachment_type}`); base columns: id (UUIDv7), attachment_type, post_id NULLABLE
  FK→posts.id CASCADE, message_id NULLABLE FK→messages.id CASCADE, created_at;
  `CheckConstraint("post_id IS NOT NULL OR message_id IS NOT NULL")`; child tables: `AttachmentText` (content TEXT),
  `AttachmentArtistPost` (content TEXT), `AttachmentSpotifyLink` (url VARCHAR(512), track_id VARCHAR(64) NULLABLE),
  `AttachmentSoundCloudLink` (url VARCHAR(512), track_id VARCHAR(64) NULLABLE), `AttachmentAudioFile` (storage_key
  VARCHAR(512), mime_type VARCHAR(64), size_bytes BIGINT), `AttachmentVideoFile` (storage_key VARCHAR(512), mime_type
  VARCHAR(64), size_bytes BIGINT); each child PK is also FK→attachments.id CASCADE
- [x] T018 [P] Implement `MessageThread`, `MessageThreadParticipant`, `Message` ORM models in
  `backend/src/models/message.py`; `MessageThread`: id (UUIDv7), created_at; `MessageThreadParticipant`: composite PK (
  thread_id, user_id), both FK CASCADE; `Message`: id (UUIDv7), thread_id FK→message_threads.id CASCADE NOT NULL,
  sender_id FK→users.id SET NULL NOT NULL, created_at
- [x] T019 [P] Implement `AccessToken` and `RefreshToken` ORM models in `backend/src/models/auth.py`; `AccessToken`:
  id (UUIDv7), token_hash `LargeBinary(32)` UNIQUE NOT NULL, user_id FK→users.id CASCADE NOT NULL, expires_at
  TIMESTAMPTZ NOT NULL, revoked_at TIMESTAMPTZ NULLABLE, created_at; partial index on
  `expires_at WHERE revoked_at IS NULL`; `RefreshToken`: id (UUIDv7), token_hash `LargeBinary(32)` UNIQUE NOT NULL,
  user_id FK NOT NULL, access_token_id FK→access_tokens.id SET NULL NULLABLE, expires_at, rotated_at NULLABLE,
  revoked_at NULLABLE, created_at
- [x] T020 Configure Alembic: write `backend/alembic.ini` (script_location = migrations, sqlalchemy.url = placeholder);
  implement async `backend/migrations/env.py` using `async_engine_from_config` +
  `connection.run_sync(do_run_migrations)` + `NullPool`; import `src.models.base.Base` and all model modules so
  autogenerate detects every table; read `DATABASE_URL` env var at runtime to override ini; set `compare_type=True`,
  `compare_server_default=True` (depends on T013–T019)
- [x] T021 Generate initial Alembic migration (requires `make up` running): from `backend/` run
  `uv run alembic revision --autogenerate -m "initial_schema"`; verify the generated file in
  `backend/migrations/versions/` contains all 13 tables and 4 enums; rename file to `0001_initial_schema.py` and verify
  `uv run migrate` applies cleanly
- [x] T022 Implement `get_current_user` async dependency in `backend/src/core/deps.py`: (1) skip auth if
  `request.scope["endpoint"]` has `__public__ == True`; (2) extract `Authorization: Bearer <token>` header → 401 if
  missing; (3) `hash_token(raw)` → SELECT from
  `access_tokens WHERE token_hash=$1 AND expires_at > now() AND revoked_at IS NULL` → 401 if not found; (4) load
  associated `User` → 403 if `status == disabled`; (5) attach `User` to `request.state.user`; return `User`
- [x] T023 Create FastAPI app factory `create_app(settings: Settings | None = None) -> FastAPI` in
  `backend/src/main.py`: `@asynccontextmanager lifespan` calls `engine.dispose()` on shutdown; register root API router;
  add global exception handlers for `RequestValidationError` (422) and unhandled exceptions (500) returning
  `{"detail": "..."}` envelope; `openapi_url="/v1/openapi.json"`
- [x] T024 Create root router in `backend/src/api/router.py` that includes the v1 router at prefix `/v1`; update
  `backend/src/api/v1/__init__.py` to define the v1 `APIRouter` that will be populated by health and auth sub-routers;
  include v1 router in `backend/src/api/router.py`
- [x] T025 Create `backend/tests/conftest.py` with async fixtures: `settings` (monkeypatched test DB URL), `app` (
  `create_app(settings)`), `async_client` (`httpx.AsyncClient` with `ASGITransport(app=app)`, `base_url="http://test"`),
  `db_session` (begin savepoint, yield `AsyncSession`, rollback to savepoint after each test for isolation)

**Checkpoint**: `make up && cd backend && uv run migrate && uv run dev` starts without errors. The FastAPI app factory
boots, migrations apply, no endpoint 404s yet for /v1/health.

---

## Phase 3: User Story 1 — Health Check (P1) 🎯 MVP

**Goal**: Confirm the FastAPI app is reachable and returns `{"status":"ok","version":"0.1.0"}` with no auth required —
validates app factory, lifespan, public endpoint annotation, and router mounting.

**Independent Test**: `curl http://localhost:8000/v1/health` → `200 {"status":"ok","version":"0.1.0"}`

- [x] T026 [P] [US1] Write contract test for `GET /v1/health` in `backend/tests/contract/test_health_contract.py`:
  assert status 200, body exactly `{"status":"ok","version":"0.1.0"}`, no `Authorization` header required; confirm test
  fails before T027 is implemented
- [x] T027 [US1] Implement `GET /v1/health` in `backend/src/api/v1/health.py`: define `HealthResponse(BaseModel)` with
  `status: str` and `version: str`; `@router.get("/health", response_model=HealthResponse)` decorated with
  `@public_endpoint`; version from `importlib.metadata.version("backend")`; include `health.router` in the v1 router
- [x] T028 [US1] Write unit tests for `Settings` in `backend/tests/unit/test_config.py`: default field values,
  `SecretStr` not exposed in `repr()`, `postgres://` → `postgresql+asyncpg://` normalisation, `lru_cache` singleton (
  monkeypatch env vars to reset between tests)

**Checkpoint**: `uv run test -k health` passes; live `GET /v1/health` → 200. US1 independently functional.

---

## Phase 4: User Story 2 — User Registration (P2)

**Goal**: A new visitor can `POST /v1/auth/register` with email + username + password and receive an access/refresh
token pair. Duplicate email or username returns 409.

**Independent Test**: `POST /v1/auth/register {"email":"a@b.com","username":"alice","password":"S3cur3P@ss!"}` →
`201 {"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":900}`

- [x] T029 [P] [US2] Write contract tests for `POST /v1/auth/register` in
  `backend/tests/contract/test_auth_contract.py`: 201 + correct token response shape on valid input; 400 on invalid
  email format; 400 on password < 8 chars; 400 on username < 3 chars; 409 on duplicate email; 409 on duplicate username;
  all assertions fail before T030–T031
- [x] T030 [US2] Implement `AuthService` class in `backend/src/services/auth.py` with
  `async register(session, email, username, password) -> TokenPair`: hash password with `hash_password`; create `User`
  row (uuid6.uuid7 PK, status=pending); generate two token pairs via `generate_token()`; insert `AccessToken` row (TTL
  from settings) and `RefreshToken` row; return `TokenPair(access_token, refresh_token, expires_in)`; catch UNIQUE
  violations and raise `EmailTakenError` / `UsernameTakenError` custom exceptions
- [x] T031 [US2] Implement `POST /v1/auth/register` in `backend/src/api/v1/auth.py`: define `RegisterRequest(BaseModel)`
  with email/username/password field validators (email format, 3–50 char username, 8–128 char password); define
  `TokenResponse(BaseModel)`; handler calls `AuthService.register`, returns 201 `TokenResponse`; maps `EmailTakenError`/
  `UsernameTakenError` → 409; decorated `@public_endpoint`; include `auth.router` in v1 router
- [x] T032 [US2] Write integration test for registration in `backend/tests/integration/test_auth_integration.py`: POST
  to `/v1/auth/register` with real DB session; assert returned tokens are 44-char base64url strings; verify
  `access_tokens` and `refresh_tokens` rows exist in DB with correct `expires_at` values

**Checkpoint**: `uv run test -k register` passes. US2 independently functional.

---

## Phase 5: User Story 3 — User Login (P3)

**Goal**: A registered user can `POST /v1/auth/login` (OAuth2 Password Grant form) and receive a new token pair. Wrong
credentials → 401; disabled account → 403; existing tokens NOT revoked (multi-device support).

**Independent Test**: `POST /v1/auth/login` (form: `username=a@b.com&password=S3cur3P@ss!&grant_type=password`) →
`200 {"access_token":"...","refresh_token":"...","token_type":"bearer","expires_in":900}`

- [x] T033 [P] [US3] Write contract tests for `POST /v1/auth/login` in `backend/tests/contract/test_auth_contract.py`:
  200 + token shape on valid credentials; 401 on wrong password; 401 on unknown email; 403 on disabled account; 400 on
  missing `grant_type` field
- [x] T034 [US3] Implement `AuthService.login(session, email, password) -> TokenPair` in `backend/src/services/auth.py`:
  lookup `User` by email; `verify_password(plain, user.password_hash)` → raise `InvalidCredentialsError` on mismatch;
  raise `AccountDisabledError` if `status == disabled`; create new `AccessToken` + `RefreshToken` rows without revoking
  existing ones; return `TokenPair`
- [x] T035 [US3] Implement `POST /v1/auth/login` in `backend/src/api/v1/auth.py` using `OAuth2PasswordRequestForm` (
  email in the `username` field per contract); map `InvalidCredentialsError` → 401, `AccountDisabledError` → 403;
  decorated `@public_endpoint`
- [x] T036 [US3] Write integration test for login in `backend/tests/integration/test_auth_integration.py`: register
  user → login → verify two separate `access_tokens` rows in DB (one from register, one from login, neither revoked)

**Checkpoint**: `uv run test -k login` passes. US3 independently functional.

---

## Phase 6: User Story 4 — Token Refresh (P4)

**Goal**: A client with a valid refresh token can exchange it for a new access + refresh token pair. The consumed
refresh token gets `rotated_at`; the old access token gets `revoked_at`. Operation is atomic within a single
transaction.

**Independent Test**: `POST /v1/auth/refresh-token {"refresh_token":"<valid-token>"}` → `200` new pair; old
`refresh_tokens.rotated_at` is set; old `access_tokens.revoked_at` is set.

- [x] T037 [P] [US4] Write contract tests for `POST /v1/auth/refresh-token` in
  `backend/tests/contract/test_auth_contract.py`: 200 + new token pair on valid token; 401 on expired token; 401 on
  already-rotated token; 401 on revoked token; 400 on malformed (non-base64url) token
- [x] T038 [US4] Implement `AuthService.refresh_token(session, raw_refresh_token) -> TokenPair` in
  `backend/src/services/auth.py`: `hash_token(raw)` → SELECT `refresh_tokens WHERE token_hash=$1`; validate: not
  expired, not rotated, not revoked → raise `InvalidTokenError`; within single transaction:
  `UPDATE refresh_tokens SET rotated_at=now()`,
  `UPDATE access_tokens SET revoked_at=now() WHERE id=old.access_token_id`, INSERT new `AccessToken` + `RefreshToken`;
  return new `TokenPair`
- [x] T039 [US4] Implement `POST /v1/auth/refresh-token` in `backend/src/api/v1/auth.py`; define
  `RefreshRequest(BaseModel)` with `refresh_token: str`; map `InvalidTokenError` → 401; decorated `@public_endpoint`
- [x] T040 [US4] Write integration test for token rotation in `backend/tests/integration/test_auth_integration.py`:
  register → refresh → assert new tokens differ from old; assert old refresh token `rotated_at` is set; assert replayed
  old refresh token → 401

**Checkpoint**: `uv run test -k refresh` passes. US4 independently functional.

---

## Phase 7: User Story 5 — Logout (P5)

**Goal**: An authenticated user can `POST /v1/auth/logout` to synchronously revoke all active session tokens. Subsequent
requests with the old access token return 401.

**Independent Test**: `POST /v1/auth/logout` with `Authorization: Bearer <token>` → `204`; follow-up `GET /v1/health`
with same token → 401 (rejected by `get_current_user`).

- [x] T041 [P] [US5] Write contract tests for `POST /v1/auth/logout` in `backend/tests/contract/test_auth_contract.py`:
  204 on valid bearer token; 401 on missing Authorization header; 401 on expired token; 401 on already-revoked token
- [x] T042 [US5] Implement `AuthService.logout(session, user_id: uuid.UUID, access_token_id: uuid.UUID) -> None` in
  `backend/src/services/auth.py`: in a single transaction,
  `UPDATE access_tokens SET revoked_at=now() WHERE id=access_token_id`;
  `UPDATE refresh_tokens SET revoked_at=now() WHERE user_id=$1 AND revoked_at IS NULL AND access_token_id=$2`; operation
  is synchronous (no background job)
- [x] T043 [US5] Implement `POST /v1/auth/logout` in `backend/src/api/v1/auth.py`; requires auth (no
  `@public_endpoint`); inject `current_user = Depends(get_current_user)` and `db = Depends(get_db_session)`; call
  `AuthService.logout(db, current_user.id, access_token.id)`; return `Response(status_code=204)`
- [x] T044 [US5] Write integration test for logout in `backend/tests/integration/test_auth_integration.py`: register →
  logout → attempt `GET /v1/health` with old token → 401; verify DB rows have `revoked_at` set for all session tokens

**Checkpoint**: `uv run test -k logout` passes. Full auth lifecycle (register → login → refresh → logout) is end-to-end
functional.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Quality gates, security hardening, and schema publication spanning all user stories.

- [x] T045 [P] Write unit tests for `security.py` in `backend/tests/unit/test_security.py`: `generate_token()` returns
  44-char base64url string and 32-byte SHA-256 hash; `hash_token` is deterministic; `hash_password` / `verify_password`
  round-trip succeeds; wrong password → `verify_password` returns False
- [x] T046 [P] Add `backend/.gitignore` with entries: `.env`, `__pycache__/`, `*.pyc`, `.coverage`, `htmlcov/`,
  `.mypy_cache/`, `.ruff_cache/`, `dist/`
- [x] T047 Run `uv run lint` (ruff, zero errors) and `uv run format` (black + isort, no diffs) in `backend/`; fix all
  findings across `backend/src/` and `backend/tests/`
- [x] T048 Run full test suite with coverage gate: `cd backend && uv run test`; fix any uncovered lines until
  `pytest-cov` reports 100% (per `pyproject.toml` `fail_under=100` setting)
- [x] T049 Export OpenAPI schema: start dev server (`uv run dev`), then
  `curl http://localhost:8000/v1/openapi.json | python3 -m json.tool > shared/openapi.json`; create `shared/` directory
  if absent; commit `shared/openapi.json`
- [x] T050 Validate quickstart end-to-end: follow `specs/001-initialize-backend-project/quickstart.md` from a clean
  state — `make up`, `cd backend && uv run migrate`, `uv run dev`, smoke test each endpoint from the contract; confirm
  all pass

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 — **blocks all user stories**
- **US1 Health (Phase 3)**: Depends on Phase 2 only
- **US2 Register (Phase 4)**: Depends on Phase 2 only
- **US3 Login (Phase 5)**: Depends on Phase 4 (shares `AuthService` + `User` model)
- **US4 Refresh (Phase 6)**: Depends on Phase 4 (shares token row schema)
- **US5 Logout (Phase 7)**: Depends on Phase 4 (requires active session from register)
- **Polish (Phase N)**: Depends on all user story phases

### User Story Dependencies

| Story        | Depends On           | Independent Test                |
|--------------|----------------------|---------------------------------|
| US1 Health   | Phase 2 only         | `curl /v1/health` → 200         |
| US2 Register | Phase 2 only         | 201 with token pair             |
| US3 Login    | US2 (AuthService)    | 200 token pair on valid creds   |
| US4 Refresh  | US2 (token schema)   | New tokens, old rotated/revoked |
| US5 Logout   | US2 (active session) | 204, old token → 401            |

### Within Each User Story

- Contract tests written first → must fail → implement service → implement endpoint → integration tests
- `AuthService` grows incrementally: T030 (register) → T034 (login) → T038 (refresh) → T042 (logout)

### Parallel Opportunities

- **Phase 1**: T001 + T002 (compose.yml and Makefile in different files)
- **Phase 2**: T009 + T010 + T011 (config / decorator / security — different files); T014 + T015 + T016 + T017 + T018 +
  T019 (six ORM model files — all different)
- **Phase 3**: T026 + T028 (contract test + unit test — different files)
- **Phase N**: T045 + T046 + T047 (different concerns, different files)

---

## Parallel Example: Phase 2 ORM Models (T014–T019)

```bash
# All six model files share only base.py and can be written in parallel:
T014: backend/src/models/user.py        (User, AdminUser)
T015: backend/src/models/friend.py      (Friend)
T016: backend/src/models/post.py        (Post)
T017: backend/src/models/attachment.py  (Attachment hierarchy)
T018: backend/src/models/message.py     (MessageThread, Message)
T019: backend/src/models/auth.py        (AccessToken, RefreshToken)
```

---

## Implementation Strategy

### MVP First (Health check only — Phases 1–3, 28 tasks)

1. Complete Phase 1: Setup (T001–T007)
2. Complete Phase 2: Foundational (T008–T025) — **critical path**
3. Complete Phase 3: US1 Health (T026–T028)
4. **STOP and VALIDATE**: `GET /v1/health` → 200 in live server
5. Scaffold is demonstrable; all quality gates enforced

### Incremental Delivery

1. Phases 1–2 → scaffold running with migrations applied (T001–T025)
2. Phase 3 → `GET /v1/health` working (T026–T028)
3. Phase 4 → users can register (T029–T032)
4. Phases 5–7 → complete auth flow: login, refresh, logout (T033–T044)
5. Phase N → 100% coverage, OpenAPI published, quickstart validated (T045–T050)

### Parallel Team Strategy (after Phase 2 completes)

- Developer A: US1 Health (T026–T028) — no auth dependency
- Developer B: US2 Register (T029–T032) — first auth story
- Developer C: US3–US5 contract tests (T033, T037, T041) — write tests while US2 implements

---

## Notes

- `[P]` tasks target different files — safe to run in parallel without merge conflicts
- `[Story]` labels map to endpoint-derived user stories US1–US5 (no spec.md; derived from `contracts/auth-api.md`)
- `uuid6.uuid7()` is the Python-side PK default on every model — `gen_random_uuid()` is never used
- `make up` must be running before T021 (autogenerate migration) and T050 (quickstart validation)
- `tests/contract/` = request/response shape and HTTP status code validation (in-process ASGI, no real DB required)
- `tests/integration/` = full DB round-trips using the `db_session` fixture with rollback isolation
- Commit after each checkpoint: T025, T028, T032, T036, T040, T044, T050