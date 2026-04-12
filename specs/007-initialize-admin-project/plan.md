# Implementation Plan: Initialize Admin UI Project

**Branch**: `007-initialize-admin-project` | **Date**: 2026-03-17 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/007-initialize-admin-project/spec.md`

## Summary

Initialize a dedicated browser-based admin application in `admin/` using `React 19 + TypeScript + Vite`, with
`React Router` for navigation, `TanStack Query` for REST API state, `React Hook Form 8 + Zod 4` for validated forms, and
`shadcn/ui + Tailwind` for the component system, plus `Biome` for JavaScript/TypeScript linting and formatting. The app
will authenticate against the admin-only `/admin/v1/...`
backend surface, provide foundations for user management, content moderation, friend-relationship management, and
explicitly exclude all message-management capabilities while keeping builds and local development fast.

## Technical Context

**Language/Version**: TypeScript 5.x on Node.js 24  
**Primary Dependencies**: React 19, Vite, React Router, TanStack Query 5, React Hook Form 8, Zod 4, Tailwind CSS,
shadcn/ui, Biome, Vitest, React Testing Library, Playwright  
**Storage**: No frontend database; browser session state only, with admin authentication delegated to backend-issued
opaque tokens transported through backend-controlled session credentials  
**Testing**: Vitest, React Testing Library, Playwright, MSW for API mocking in component tests  
**Target Platform**: Modern evergreen desktop browsers for internal admin use  
**Project Type**: Web application (SPA) in the monorepo under `admin/`  
**Performance Goals**: Vite dev server cold start under 2 seconds on a typical developer laptop; production build under
30 seconds in CI; route transitions and moderation feedback under 100 ms perceived latency aside from network time  
**Constraints**: No SSR; canonical admin API prefix is `/admin/v1/...`; separate admin authorization from end-user auth;
no message access UI; resource-efficient builds and installs are required; destructive actions must surface auditable
outcomes  
**Scale/Scope**: One new admin SPA with route guards, shared layout, domain slices for auth, managed user/content
moderation, friend relationships, and the initial moderation workflows described in the spec

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle                                | Status | Notes                                                                                                                                                                                                                               |
|------------------------------------------|--------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| I. Code Quality & Standards              | ✅ PASS | `tsc --noEmit` and `biome check` will be added for the admin app; feature code is decomposed by domain slice to preserve single responsibility                                                                                      |
| II. Test-First Discipline                | ✅ PASS | Admin routes, forms, and moderation flows will be specified through failing Vitest/component tests and Playwright scenarios before implementation                                                                                   |
| III. API Contract Integrity              | ✅ PASS | Admin UI consumes only `/admin/v1/...` endpoints, treats admin authentication tokens as opaque backend-owned credentials validated server-side, and requires OpenAPI updates in `shared/openapi.json` when backend contracts change |
| IV. User Experience Consistency          | ✅ PASS | Every page will define loading, empty, error, and success states; destructive actions require explicit confirmation and human-readable feedback                                                                                     |
| V. Performance Standards                 | ✅ PASS | Vite and pnpm minimize local resource usage; query caching, route-level code splitting, and virtualized tables prevent unnecessary UI and network work                                                                              |
| VI. Security by Design                   | ✅ PASS | Admin auth remains separate, message access is omitted by design, sensitive data is excluded from client logs, and session handling stays backend-controlled                                                                        |
| VII. Localisation & Internationalisation | ✅ PASS | User-facing strings will be centralized in an i18n-ready message layer with English as the initial locale; no hardcoded copy in reusable primitives                                                                                 |
| VIII. Clean Architecture                 | ✅ PASS | The admin app mirrors the constitution’s inner-to-outer layering with per-feature `domain/`, `data/`, and `presentation/` modules plus import-boundary checks                                                                       |
| Tech Stack & Monorepo Structure          | ✅ PASS | The constitution now formally includes the root-level `admin/` React + TypeScript + Vite application and its supporting toolchain                                                                                                   |
| Quality Gates                            | ✅ PASS | The feature will add admin-specific lint, typecheck, unit/component, e2e, and build gates without weakening existing backend/mobile gates                                                                                           |

**Post-Phase 1 re-check**: All functional and architectural gates still pass, including the admin web stack and monorepo
structure requirements.

## Project Structure

### Documentation (this feature)

```text
specs/007-initialize-admin-project/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/
│   └── admin-ui.md      # UI/API interaction contract
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
admin/
├── src/
│   ├── app/
│   │   ├── router/
│   │   │   └── index.tsx                # React Router config and protected routes
│   │   ├── providers/
│   │   │   ├── query-client.tsx         # TanStack Query provider
│   │   │   └── theme-provider.tsx       # Theme + UI provider wiring
│   │   └── main.tsx                     # Vite entry point
│   ├── core/
│   │   ├── api/
│   │   │   ├── http-client.ts           # Fetch wrapper, auth/session handling, Zod parsing
│   │   │   └── query-keys.ts            # Shared query key factory
│   │   ├── auth/
│   │   │   └── route-guard.tsx          # Admin-only guard and session bootstrap
│   │   ├── config/
│   │   │   └── env.ts                   # `VITE_*` config parsing
│   │   └── routing/
│   │       └── route-definitions.ts     # Route path constants
│   ├── features/
│   │   ├── auth/
│   │   │   ├── domain/
│   │   │   │   ├── entities/
│   │   │   │   ├── use_cases/
│   │   │   │   └── ports/
│   │   │   ├── data/
│   │   │   └── presentation/
│   │   ├── dashboard/
│   │   ├── users/
│   │   ├── content/
│   │   └── friend-relationships/
│   │       ├── domain/
│   │       ├── data/
│   │       └── presentation/
│   └── shared/
│       ├── ui/                          # shadcn/ui primitives and composed admin widgets
│       ├── layout/                      # App shell, nav, breadcrumbs
│       ├── table/                       # Reusable table/filter helpers
│       ├── forms/                       # Shared form helpers
│       └── lib/                         # Utility functions (`cn`, date formatting, etc.)
├── tests/
│   ├── unit/
│   ├── component/
│   └── e2e/
├── public/
├── components.json                      # shadcn/ui registry config
├── index.html
├── package.json
├── pnpm-lock.yaml
├── tsconfig.json
├── vite.config.ts
├── vitest.config.ts
├── playwright.config.ts
├── tailwind.config.ts
├── postcss.config.mjs
└── biome.json

backend/
├── src/backend/
│   ├── domain/
│   ├── application/
│   │   ├── use_cases/
│   │   └── ports/
│   ├── core/               # deps, settings, security helpers
│   ├── presentation/
│   │   └── api/v1/
│   └── infrastructure/
│       └── persistence/
│           ├── models/
│           └── repositories/
└── tests/
    ├── contract/
    ├── integration/
    └── unit/
```

**Structure Decision**: Use a dedicated root-level `admin/` SPA, consistent with the monorepo ADR, and organize it with
the same Clean Architecture intent already mandated elsewhere in the repo. Shared app wiring lives in `admin/src/app/`
and `admin/src/core/`; business-facing slices live in `admin/src/features/*`; reusable primitives live in
`admin/src/shared/`. Backend additions for this feature follow the real repo layout under `backend/src/backend/`: domain entities in `domain/`, use cases in `application/use_cases/`, dependency wiring in `core/`, FastAPI routers in `presentation/api/v1/`, and persistence in `infrastructure/persistence/{models,repositories}/`. Admin moderation APIs return managed admin-facing projections over operational records.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|--------------------------------------|
| None      | N/A        | N/A                                  |
