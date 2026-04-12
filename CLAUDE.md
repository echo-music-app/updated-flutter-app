# echo Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-02-25

## Active Technologies
- Python 3.13 (backend); YAML (GitHub Actions workflows) + `astral-sh/setup-uv@v7`, `docker/build-push-action@v6`, `docker/metadata-action@v5`, `docker/login-action@v3`, `docker/setup-buildx-action@v3`, `actions/checkout@v6` (002-github-actions-ci-cd)
- PostgreSQL 17 (service container for tests only; N/A for production image) (002-github-actions-ci-cd)
- Dart (Flutter 3.x stable channel) + `flutter_localizations` (SDK), `intl ^0.20.2`, `flutter_secure_storage ^10.0.0`, `flutter_lints ^6.0.0` (003-initialize-flutter-project)
- N/A (no persistent storage in this feature) (003-initialize-flutter-project)
- Dart (Flutter 3.x stable channel) + `flutter_localizations` (SDK), `intl ^0.20.2`, `flutter_secure_storage ^10.0.0` (web impl (003-initialize-flutter-project)
- Dart (Flutter 3.x stable) + Python 3.13; `spotify_sdk ^3.0.2`, `flutter_inappwebview ^6.1.0`, `dio ^5.x`, `cached_network_image ^3.4.0`, `app_links ^7.0.0`, `url_launcher ^6.x`; backend: `httpx`, `cryptography` (004-spotify-player-poc)
- PostgreSQL 18 — new `spotify_credentials` table (AES-256-GCM encrypted token columns); mobile `flutter_secure_storage` for Echo opaque tokens (004-spotify-player-poc)

- Python 3.13+ + FastAPI, SQLAlchemy 2.0 (async), Alembic, Pydantic v2, pydantic-settings, asyncpg, uvicorn, pytest, black, ruff, isort (001-initialize-backend-project)

## Project Structure

```text
backend/          # FastAPI application (Python 3.13, uv)
mobile/           # Flutter application (Android + iOS)
shared/           # OpenAPI schema and cross-concern artifacts
specs/            # Feature specifications and plans
docs/             # Architecture documentation
```

## Commands

```bash
# Backend (run from backend/)
uv sync --dev         # install deps from lockfile
uv run alembic revision --autogenerate -m "describe_change"
```

```bash
# Backend (run from project root)
make up               # (re-)start local environment
make up-once          # start local environment if it's not running
make dev              # start dev server (uvicorn --reload :8000)
make test             # pytest with coverage
make test-no-coverage # pytest without coverage
make lint             # ruff check
make format           # black + isort
make ruff-fix         # ruff check --fix
make migrate          # alembic upgrade head
```

## Code Style

- Python: `black` + `isort` formatting, `ruff` linting, zero errors required
- Type annotations on all public functions and method signatures
- Functions ≤40 lines; single responsibility per module/class
- Dependency management via `uv` only — no `pip install` directly

## Recent Changes
- 004-spotify-player-poc: Added Dart (Flutter 3.x stable) + Python 3.13 + `spotify_sdk ^3.0.2`, `flutter_inappwebview ^6.1.0`, `dio ^5.x`, `cached_network_image ^3.4.0`, `app_links ^7.0.0`, `url_launcher ^6.x`; backend: FastAPI, SQLAlchemy (async), Alembic, `httpx` (move to prod deps), `cryptography`
- 004-spotify-player-poc: Dual-screen plan — native SDK screen (/player) unchanged; new WebView iframe screen (/player-webview) via flutter_inappwebview
- 003-initialize-flutter-project: Added Dart (Flutter 3.x stable channel) + `flutter_localizations` (SDK), `intl ^0.19.0`, `flutter_secure_storage ^9.2.2` (web impl


<!-- MANUAL ADDITIONS START -->
* Use Context7 for documentation and example lookup
* Use Serena to discover references instead of reading files, if possible
* Use https://github.com/flutter/samples/tree/main/compass_app as an example for the flutter application
* Use `make test test-args="<pytest parameters>"` to run pytest with specific parameters
<!-- MANUAL ADDITIONS END -->
