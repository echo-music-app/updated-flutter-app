# Echo — Project Overview

**Purpose**: "Echo" is a social music-sharing app. Users create posts (likely tied to music/tracks), have friends, and connect with Spotify for playback. The backend exposes a REST API consumed by a Flutter mobile app.

## Tech Stack

### Backend
- Python 3.13, FastAPI (with standard extras), SQLAlchemy 2.0 (async), Alembic, Pydantic v2, pydantic-settings
- asyncpg (PostgreSQL driver), bcrypt, httpx, cryptography, uuid6
- uv for dependency management

### Mobile
- Flutter 3.x stable (Dart), flutter_secure_storage, spotify_sdk, flutter_inappwebview, dio, cached_network_image

### Infrastructure
- PostgreSQL (17 for CI, 18 in prod schema discussions)
- Docker Compose for local dev
- GitHub Actions CI/CD

## Repository Layout
```
backend/    FastAPI app (Python 3.13, uv)
mobile/     Flutter app (Android + iOS)
shared/     OpenAPI schema and cross-concern artifacts
specs/      Feature specifications and plans
docs/       Architecture documentation
```
