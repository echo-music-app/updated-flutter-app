# Feature Specification: GitHub Actions CI/CD

**Branch**: `002-github-actions-ci-cd`
**Date**: 2026-02-28
**Status**: Draft

## Overview

Set up GitHub Actions workflows to:
1. Run the full backend test suite (with linting and formatting checks) on every commit/push to any branch and on pull requests to `main`.
2. Build a Docker image of the backend service and publish it to a container registry on every merge to `main`.

## Goals

- Automate quality gates: every push triggers linting, formatting, and tests.
- Every merge to `main` produces a versioned Docker image for deployment.
- Keep CI fast: parallel jobs where possible; cache dependencies.

## Non-Goals

- Mobile (Flutter) CI is out of scope for this feature.
- Deployment/CD to a live environment is out of scope; only image publishing is required.
- Multi-arch Docker builds are not required initially.

## Requirements

### CI — Test Workflow (every push / PR)

1. Triggered on: `push` to any branch, `pull_request` targeting `main`.
2. Jobs:
   - **lint**: `uv run lint` (ruff), `uv run format` checks (black --check, isort --check).
   - **test**: `uv run test` (pytest with coverage); coverage must meet the configured threshold.
3. Python version: 3.13.
4. Dependencies installed via `uv sync --dev` with caching.
5. A PostgreSQL service container is required for integration tests.

### CD — Docker Build & Publish Workflow (on merge to main)

1. Triggered on: `push` to `main` branch only.
2. Build a Docker image from `backend/Dockerfile` (to be created).
3. Publish image to GitHub Container Registry (ghcr.io) tagged with:
   - `latest`
   - Short Git SHA (e.g., `sha-abc1234`)
4. Docker layer caching via GitHub Actions cache.
5. Image metadata labels (OCI standard) populated automatically.

## Acceptance Criteria

- [ ] Push to a feature branch triggers CI and results in a pass/fail status on the commit.
- [ ] A PR to `main` shows CI checks that must pass before merge.
- [ ] Merging to `main` triggers image build and pushes to ghcr.io.
- [ ] Image is pullable with `docker pull ghcr.io/<owner>/echo-backend:latest`.
- [ ] No secrets are hardcoded; registry auth uses `GITHUB_TOKEN`.

## Open Questions

- None — GITHUB_TOKEN is available by default in GitHub Actions; no external secrets needed for ghcr.io publishing.
