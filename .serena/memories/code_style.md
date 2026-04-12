# Code Style & Conventions (Backend — Python)

## Formatting
- `black` with `line-length = 140`
- `isort` with `profile = "black"`, `line_length = 140`
- `ruff` lint rules: E, F, I, UP

## Type Annotations
- All public functions and method signatures must have type annotations.

## Functions / Classes
- Functions ≤ 40 lines; single responsibility per module/class.
- No docstrings required unless logic is non-obvious.

## Dependency Management
- `uv` only — never `pip install` directly.

## Testing
- pytest with `asyncio_mode = "auto"` (all async tests auto-detected).
- Coverage must be 100% (some ORM model files are excluded via `omit`).
- Tests live in `backend/tests/` with subdirs: `unit/`, `integration/`, `contract/`.

## Naming
- snake_case for Python identifiers.
- Repository interfaces: `<Entity>Repository` in domain layer.
- Concrete repos: `<Entity>Repository` in infrastructure layer (same name, different module).
