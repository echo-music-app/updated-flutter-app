# ---- builder ----
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS builder

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_NO_DEV=1 \
    UV_PYTHON_DOWNLOADS=0

WORKDIR /app

# Install third-party dependencies only (cached layer; invalidated only when uv.lock changes)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --no-install-project

# Copy source and install the project package
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked

# ---- dev ----
FROM ghcr.io/astral-sh/uv:python3.13-bookworm-slim AS dev

ENV UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=0 \
    UV_PROJECT_ENVIRONMENT=/venv \
    UV_NO_CACHE=1

WORKDIR /app

# Install third-party dependencies only (cached layer; invalidated only when uv.lock changes)
RUN --mount=type=cache,target=/root/.cache/uv \
    --mount=type=bind,source=uv.lock,target=uv.lock \
    --mount=type=bind,source=pyproject.toml,target=pyproject.toml \
    uv sync --locked --dev --no-install-project

# Install the project package with dev deps into /venv (outside the mounted volume)
COPY . /app
RUN --mount=type=cache,target=/root/.cache/uv \
    uv sync --locked --dev

ENV PATH="/venv/bin:$PATH"

EXPOSE 8000
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]

# ---- runtime ----
FROM python:3.13-slim-bookworm AS prod

RUN groupadd --system --gid 999 appuser \
 && useradd --system --gid 999 --uid 999 --no-create-home appuser

COPY --from=builder --chown=appuser:appuser /app /app

ENV PATH="/app/.venv/bin:$PATH"

USER appuser
WORKDIR /app

EXPOSE 8000
CMD ["uvicorn", "backend.main:app", "--host", "0.0.0.0", "--port", "8000"]
