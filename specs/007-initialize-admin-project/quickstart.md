# Quickstart: Initialize Admin UI Project

## Prerequisites

- Node.js 24 installed
- `corepack` enabled so `pnpm` is available
- Backend admin APIs available locally under `/admin/v1/...`
- A browser supported by the admin workspace (latest Chrome, Edge, Firefox, or Safari)

## First-Time Setup

```bash
# From repo root
corepack enable
pnpm install --dir admin
```

Create `admin/.env`:

```dotenv
VITE_APP_NAME=Echo Admin
VITE_API_BASE_URL=http://localhost:8000
```

## Running the Admin App

```bash
# From repo root
pnpm --dir admin dev
```

Expected local behavior:

- Vite serves the admin SPA with hot module replacement
- The SPA calls backend endpoints under `${VITE_API_BASE_URL}/admin/v1/...`
- Protected routes redirect unauthenticated operators to `/login`

## Production Build

```bash
# From repo root
pnpm --dir admin build
pnpm --dir admin preview
```

Output:

- Static assets in `admin/dist/`

## Linting and Type Checking

```bash
# From repo root
pnpm --dir admin biome check .
pnpm --dir admin typecheck
```

## Running Tests

```bash
# From repo root
pnpm --dir admin test
pnpm --dir admin test:e2e
```

Recommended test split:

- `test`: Vitest unit + component coverage
- `test:e2e`: Playwright browser flows for sign-in gates and moderation happy paths

## shadcn/ui Workflow

```bash
# From repo root
pnpm --dir admin dlx shadcn@latest init
pnpm --dir admin dlx shadcn@latest add button input dialog table badge toast
```

Use generated primitives only through:

- `admin/src/shared/ui/` for low-level components
- feature-level wrappers for moderation-specific interactions

## Suggested Local Development Order

1. Start the backend locally so `/admin/v1/...` responds
2. Start the admin dev server
3. Verify unauthenticated access redirects to `/login`
4. Verify an active admin session reaches the protected shell
5. Build one route at a time: users, content, friend relationships

## Route Map

```text
/login
/
/users
/users/:userId
/content
/content/:contentId
/friend-relationships
/friend-relationships/:relationshipId
```

## Navigation and UX Rules

- All protected pages must render explicit loading, empty, error, and success states
- Destructive actions must require confirmation
- Message-management screens must not exist
- Human-readable confirmation feedback should surface after every successful mutation

## CI Expectations

The admin pipeline should run only when `admin/**` or shared frontend workflow files change and should include:

- dependency install
- biome lint/format checks
- typecheck
- unit/component tests
- Playwright smoke coverage
- production build

## Pre-Push Checklist

```bash
pnpm --dir admin biome check .
pnpm --dir admin typecheck
pnpm --dir admin test
pnpm --dir admin build
```

If the backend contract changes while implementing the admin UI:

- update backend tests first
- regenerate and commit `shared/openapi.json`
- re-run frontend tests against the updated contract
