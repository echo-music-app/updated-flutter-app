# Research: Initialize Admin UI Project

## Project Scaffold and Package Manager

**Decision:** Initialize the admin application in `admin/` as a standalone Vite React TypeScript project and manage dependencies with `pnpm`.

**Rationale:** Vite gives the fastest feedback loop for a non-SSR admin SPA, which directly matches the requirement for quick and resource-efficient builds. `pnpm` reduces install size and repeated CI/network work through its content-addressable store while still keeping `admin/` independently buildable.

**Alternatives considered:**
- `Next.js` — rejected because SSR is not required and the extra framework/runtime complexity does not improve an internal admin console.
- `npm` — acceptable, but slower and more disk-heavy for repeated local and CI installs.
- `yarn` — viable, but offers no strong advantage here over `pnpm` for a new single-app Node workspace.

---

## Routing Strategy

**Decision:** Use `React Router` with `createBrowserRouter`, a protected admin shell route, and feature routes for login, dashboard, users, user detail, content, content detail, friend relationships, and relationship detail.

**Rationale:** The admin UI is fundamentally route-driven: operators move between searchable list screens, detail views, and moderation forms. A protected shell keeps navigation, breadcrumbs, and session enforcement centralized while feature modules stay isolated.

**Alternatives considered:**
- File-based routing via another framework — rejected because the project does not need SSR or framework-specific conventions.
- A custom router wrapper — rejected because React Router already covers guards, nested layouts, and history handling.

---

## API State and HTTP Boundary

**Decision:** Use `TanStack Query` for all server state, backed by a thin `fetch`-based HTTP client that normalizes errors, applies `credentials: 'include'` for admin session requests, and validates critical responses with Zod at the boundary.

**Rationale:** TanStack Query is the best fit for REST-heavy admin surfaces with searchable tables, detail pages, optimistic invalidation, and mutation feedback. A thin HTTP adapter prevents transport concerns from leaking into UI components and supports Clean Architecture boundaries.

**Alternatives considered:**
- Global state via Redux Toolkit — rejected because most admin data is server state, not client state.
- Ad hoc `useEffect` + `fetch` — rejected because cache invalidation, retries, and loading/error coordination become repetitive and error-prone.

---

## Form Handling and Validation

**Decision:** Use `React Hook Form` for form state and `Zod` as the canonical schema layer for client validation, request normalization, and selected response parsing.

**Rationale:** Moderation forms need low-re-render cost, precise validation messaging, and shared schemas for query params and mutation payloads. `React Hook Form` and Zod integrate cleanly and keep forms lightweight.

**Alternatives considered:**
- Formik — rejected because it is heavier and less efficient for large forms.
- Client validation only in HTML attributes — rejected because admin actions require stronger, typed validation guarantees.

---

## UI System and Styling

**Decision:** Use Tailwind CSS with `shadcn/ui` primitives, and compose higher-level admin widgets for tables, filters, confirmation dialogs, badges, and toast feedback.

**Rationale:** `shadcn/ui` provides accessible, copy-local components without the runtime and bundle overhead of heavier component libraries. Tailwind keeps styling consistent and fast to iterate on. This combination is better aligned with the build-efficiency requirement than larger all-in-one UI frameworks.

**Alternatives considered:**
- MUI — rejected because it speeds up scaffolding but adds more runtime weight and imposes a stronger design system.
- Raw Tailwind only — rejected because a moderation console still benefits from accessible primitives and standardized overlay/menu/form behavior.

---

## Authentication Model for the Admin SPA

**Decision:** Treat admin authentication as a dedicated backend-managed session under `/admin/v1/auth/*`, with the browser sending credentials automatically and the UI bootstrapping session state from a dedicated session-read endpoint before protected routes render.

**Rationale:** The spec requires independent admin authorization and a distinct admin user base. A backend-managed browser session keeps opaque credential handling out of application code and avoids unsafe token persistence in `localStorage`. The SPA only tracks derived session state such as `authenticated`, `unauthenticated`, and `expired`.

**Alternatives considered:**
- Persisting bearer tokens in `localStorage` — rejected for security reasons.
- Sharing the end-user auth flow — rejected because the spec requires separate admin authorization semantics.

---

## Testing Strategy

**Decision:** Use:
- Vitest for unit tests around query mappers, schema parsing, and use-case helpers
- React Testing Library for route and component behavior
- MSW for component-test API mocking
- Playwright for critical end-to-end admin flows

**Rationale:** This provides fast local feedback and preserves test-first discipline for an SPA. Unit/component tests cover most UI logic cheaply; Playwright validates auth gates and destructive moderation paths realistically.

**Alternatives considered:**
- Cypress — viable, but Playwright offers broader browser coverage and strong parallel execution.
- E2E-only coverage — rejected because it is slower, more brittle, and poor at isolating UI edge cases.

---

## Clean Architecture Adaptation for the Admin App

**Decision:** Mirror the constitution’s layer boundaries inside `admin/` by separating:
- `domain/` for entities, schemas, and use-case helpers
- `data/` for REST adapters
- `presentation/` for route components and UI state
- `core/` for cross-feature infrastructure like routing, HTTP, and environment configuration

**Rationale:** Even though the constitution documents backend/mobile examples, the underlying Dependency Rule still applies well to the admin SPA. This layout makes route-level features testable and keeps API transport details out of presentation components.

**Alternatives considered:**
- A flat `components/hooks/api` frontend folder layout — rejected because admin workflows cross several domains and will become harder to maintain as the console grows.

---

## Build, CI, and Deployment Shape

**Decision:** Build the admin app as static assets with `vite build`, serve it behind the existing platform ingress or CDN, and add isolated CI jobs for install, lint, typecheck, test, build, and Playwright smoke coverage on changed `admin/**` paths.

**Rationale:** Static deployment keeps the runtime small and matches the no-SSR requirement. Isolated frontend jobs preserve monorepo build efficiency and prevent the admin app from slowing unrelated backend/mobile pipelines.

**Alternatives considered:**
- Serving the SPA from the FastAPI process directly — rejected because it couples backend and frontend release concerns and weakens independent build/test boundaries.
