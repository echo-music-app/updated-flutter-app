# Suggested Commands

All backend commands run from the `backend/` directory using `uv run`.

## Backend
```bash
cd backend

uv sync --dev                                      # install/sync deps
uv run dev                                         # start dev server (uvicorn --reload :8000)
uv run test                                        # pytest with coverage
uv run lint                                        # ruff check
uv run format                                      # black + isort
uv run migrate                                     # alembic upgrade head
uv run alembic revision --autogenerate -m "name"   # generate migration
```

## Git / Shell (Windows MINGW64 / bash)
Standard unix commands work in MINGW64 bash: `ls`, `cat`, `grep`, `find`, `cd`, `git`, etc.

## Docker
```bash
docker compose up          # start all services
docker compose up backend  # start backend only
```

## Mobile (Flutter)
```bash
cd mobile
flutter pub get
flutter run
```
