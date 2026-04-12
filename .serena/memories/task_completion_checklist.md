# Task Completion Checklist

After finishing any backend code change, run these from `backend/`:

1. `uv run format`   — black + isort formatting
2. `uv run lint`     — ruff check (zero errors required)
3. `uv run test`     — pytest with coverage (must stay at 100%)

If a new migration is needed:
4. `uv run alembic revision --autogenerate -m "describe_change"`
5. `uv run migrate`

For mobile changes (from `mobile/`):
- `flutter analyze`
- `flutter test`
