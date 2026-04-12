---
trigger: manual
description: 
globs: 
---

# echo Development Guidelines

Auto-generated from all feature plans. Last updated: 2026-03-15

## Active Technologies
- TypeScript 5.x on Node.js 20 LTS + React 18, Vite, React Router 6, TanStack Query 5, React Hook Form 7, Zod 3, Tailwind CSS, shadcn/ui, Vitest, React Testing Library, Playwright (007-initialize-admin-project)
- No frontend database; browser session state only, with admin authentication delegated to backend-issued opaque session credentials (007-initialize-admin-project)
- TypeScript 5.x on Node.js 24 + React 19, Vite, React Router, TanStack Query 5, React Hook Form 8, Zod 4, Tailwind CSS, shadcn/ui, Biome, Vitest, React Testing Library, Playwright (007-initialize-admin-project)
- Python 3.13+ + FastAPI, Pydantic v2, `httpx` (async clients), SQLAlchemy (existing auth/session integration), pytest (008-music-search-endpoint)
- N/A for search results (read-through aggregation only); existing PostgreSQL auth/session tables remain unchanged (008-music-search-endpoint)
- Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK, `go_router`, `provider`, `dio`, `flutter_secure_storage`, generated `AppLocalizations` (009-mobile-profile-view)
- No new persistence; existing secure token storage only (009-mobile-profile-view)
- Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK, `go_router`, `provider`, `dio`, `flutter_secure_storage`, `flutter_localizations`, `intl`, generated `AppLocalizations` (009-mobile-profile-view)
- Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK (`Material` + `SegmentedButton`), `provider`, `go_router`, `dio`, `flutter_localizations`, `intl`, generated `AppLocalizations` (010-mobile-search-screen)
- No new persistence; existing secure token storage via `AuthRepository` only (010-mobile-search-screen)

- Python 3.13+ + FastAPI, SQLAlchemy (async), Pydantic v2, pytest (005-posts-create-list-endpoints)

## Project Structure

```text
backend/
frontend/
tests/
```

## Commands

cd src [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] pytest [ONLY COMMANDS FOR ACTIVE TECHNOLOGIES][ONLY COMMANDS FOR ACTIVE TECHNOLOGIES] ruff check .

## Code Style

Python 3.13+: Follow standard conventions
Use clean architecture principles

## Recent Changes
- 010-mobile-search-screen: Added Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK (`Material` + `SegmentedButton`), `provider`, `go_router`, `dio`, `flutter_localizations`, `intl`, generated `AppLocalizations`
- 009-mobile-profile-view: Added Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK, `go_router`, `provider`, `dio`, `flutter_secure_storage`, `flutter_localizations`, `intl`, generated `AppLocalizations`
- 009-mobile-profile-view: Added Dart SDK `^3.11.0` (Flutter stable) + Flutter SDK, `go_router`, `provider`, `dio`, `flutter_secure_storage`, generated `AppLocalizations`


<!-- MANUAL ADDITIONS START -->
To run tests use `make test-no-coverage test-args="<arbitrary arguments for pytest>"`
or To run tests use `make test test-args="<arbitrary arguments for pytest>"` if coverage output is required.
<!-- MANUAL ADDITIONS END -->
