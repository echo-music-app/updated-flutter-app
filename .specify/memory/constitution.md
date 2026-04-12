<!--
SYNC IMPACT REPORT
==================
Version change: 1.3.1 → 1.4.0 (MINOR: add canonical admin web stack and
  quality gates)

Modified principles: None renamed or removed

Added/changed content:
  - Principle I > Added admin web quality standards.
  - Principle II > Added admin web test-first requirements.
  - Tech Stack > Added canonical admin web stack.
  - Tech Stack > Monorepo layout now includes `admin/`.
  - Development Workflow > Quality gates now include admin web lint/typecheck.

Removed sections: None

Templates reviewed:
  ✅ .specify/templates/plan-template.md
     Reviewed for admin web stack compatibility.
  ✅ .specify/templates/tasks-template.md
     Reviewed for admin web task compatibility.
  ✅ .specify/templates/spec-template.md
     No constitution-specific references — no update required.
  ✅ .specify/templates/checklist-template.md
     Generic template; no constitution-specific references — no update required.

Deferred TODOs: None — all placeholders resolved.
-->

# Echo Constitution

## Core Principles

### I. Code Quality & Standards

All code MUST meet the following non-negotiable quality standards before merging:

- **Python (backend)**: Code MUST be formatted with `black` and `isort`, and
  pass `ruff` linting with zero errors. Type annotations MUST be present on all
  public functions and method signatures.
- **Dart/Flutter (mobile)**: Code MUST be formatted with `dart format` and pass
  `flutter analyze` with zero warnings or errors.
- **TypeScript/Web (admin)**: Code MUST pass `biome check` with zero errors and
  `tsc --noEmit` with zero type errors. Public module boundaries MUST expose
  explicit types.
- Functions and methods MUST NOT exceed 40 lines. Longer logic MUST be
  decomposed into well-named helpers.
- Every module and class MUST have a single, clearly stated responsibility.
  Catch-all utilities are prohibited.
- No dead code, commented-out code blocks, or debug print statements MUST be
  committed to the main branch.
- Monorepo packages MUST remain independently buildable; circular cross-package
  dependencies are prohibited.

**Rationale**: A polyglot monorepo degrades quickly without enforced,
automated standards. Consistency across Python and Dart reduces cognitive
overhead and makes cross-team reviews effective.

### II. Test-First Discipline (NON-NEGOTIABLE)

Tests MUST be written before implementation and MUST demonstrably fail before
implementation begins. The Red-Green-Refactor cycle is mandatory.

- **Backend (Python/pytest)**:
  - Unit test coverage MUST be 100%, enforced in CI.
  - All service-layer logic MUST have unit tests.
  - Contract tests MUST cover every public API endpoint.
  - Integration tests MUST cover all cross-service and database interactions.
- **Admin Web (TypeScript/Vitest/Playwright)**:
  - Unit tests MUST cover pure domain and utility logic.
  - Component tests MUST cover route guards, forms, loading/empty/error states,
    and reusable UI behavior.
  - End-to-end tests MUST cover all critical admin workflows.
- **Mobile (Flutter)**:
  - Widget tests MUST cover every user-facing screen and reusable component.
  - Integration tests MUST cover all critical user flows (authentication,
    posting, messaging).
  - Golden tests SHOULD be used for design-system components to detect
    unintended visual regressions.
- Tests for a feature MUST be committed in the same PR as the implementation.
- Skipped tests MUST include a `// TODO:` comment with a linked issue number;
  permanently disabled tests are prohibited.

**Rationale**: With a Flutter frontend and a FastAPI backend sharing contracts,
untested changes break both surfaces silently. Test-first prevents regressions
and documents intent.

### III. API Contract Integrity

The API contract between backend and mobile is a first-class artifact.

- FastAPI endpoints MUST expose OpenAPI documentation; the generated schema
  MUST be committed and reviewed as part of any API-changing PR.
- Breaking API changes (removed fields, changed types, removed endpoints) MUST
  follow semantic versioning and MUST include a migration plan with a
  deprecation period of at least one release cycle.
- All authentication MUST use OAuth 2.0 with opaque tokens. Tokens MUST be
  validated server-side on every authenticated request; client-side-only
  validation is prohibited.
- Token issuance, rotation, and revocation logic MUST live exclusively in the
  backend; the mobile app MUST treat tokens as opaque strings.
- The Flutter app MUST store tokens using platform-native secure storage
  (`flutter_secure_storage` or equivalent); tokens MUST NOT be stored in
  shared preferences, local files, or memory beyond the session.
- API versioning prefix (e.g., `/v1/`) MUST be present from the first
  production release.

**Rationale**: A mobile app cannot hot-patch; API contract breaks force
store-release cycles. Opaque token handling centralises auth logic and prevents
token leakage from the client.

### IV. User Experience Consistency

The Flutter application MUST present a coherent, predictable interface.

- A shared design token package MUST define all colors, typography scales, and
  spacing values. Direct use of hardcoded hex colors or pixel values in
  widgets is prohibited.
- Every screen MUST explicitly handle all three states: loading, empty/zero
  data, and error. Unhandled states that result in a blank or broken UI are
  a blocking defect.
- All screens MUST support both light mode and dark mode using the design token
  system.
- Navigation patterns (back behavior, deep links, modal presentation) MUST be
  consistent across the app and documented in the quickstart for each feature.
- User-facing error messages MUST be human-readable and actionable. Internal
  error codes, stack traces, and server error details MUST never be displayed
  to end users.
- Accessibility: all interactive elements MUST have semantic labels compatible
  with screen readers (Flutter `Semantics` widget or equivalent).

**Rationale**: Users cannot see our architecture; they experience consistency.
Inconsistent UX erodes trust and increases support burden, especially for a
social platform where retention depends on polished interactions.

### V. Performance Standards

Performance targets are non-negotiable requirements, not post-launch
optimisations.

- **API (FastAPI)**:
  - Read endpoints (GET): p95 latency MUST be ≤200ms under expected load.
  - Write endpoints (POST/PUT/PATCH): p95 latency MUST be ≤500ms.
  - Server cold-start time MUST be ≤5 seconds in production.
  - All database queries MUST be reviewed for N+1 patterns before merging;
    ORM-generated queries MUST be inspected via query logging in development.
- **Mobile (Flutter — Android & iOS)**:
  - The app MUST maintain 60 fps on mid-range Android and iOS devices
    (≤4 GB RAM, mid-tier GPU).
  - Frame jank events (>16ms frame time) detected in profiling MUST be
    investigated and resolved before release.
  - App cold-start to first interactive frame MUST be ≤3 seconds on target
    devices.
  - Images and media attachments MUST use lazy loading and progressive
    rendering; blocking image fetches on the main thread are prohibited.
- Performance regressions identified in CI or profiling MUST be treated as
  bugs and resolved before the next release.

**Rationale**: Performance is a core feature for a social media application.
Slow feeds and janky scrolling directly reduce session length and retention,
particularly on the mobile-first audience this platform targets.

### VI. Security by Design

Security controls MUST be applied at the design phase, not added retroactively.

- Sensitive user data (email, username, bio, preferredGenres, message content)
  MUST be anonymized before logging.
- All API endpoints MUST enforce authentication by default. Explicitly public
  endpoints MUST be annotated with a
  `@public_endpoint` decorator or equivalent to make the exception visible in
  code review.
- Opaque tokens MUST be rotated on re-authentication and invalidated
  immediately on logout server-side. Token invalidation MUST be synchronous;
  background invalidation is insufficient.
- Private and friend-only attachments MUST be served via pre-signed, expiring
  URLs (e.g., S3 presigned URLs or equivalent supported by CDN). Non-expiring
  CDN links to private content are prohibited.
- Secrets (API keys, database credentials, OAuth client secrets) MUST NOT be
  committed to the repository. `.env` files MUST be listed in `.gitignore`;
  secret scanning MUST be enabled in CI.
- All user inputs at API boundaries MUST be validated and sanitised; FastAPI
  Pydantic models are the required validation layer.
- Admin users (see domain model: `AdminUser`) MUST operate under a separate
  authentication flow with elevated audit logging.

**Rationale**: The domain model contains sensitive personal data and private
content. A single security failure in a social platform results in irreversible
reputational damage and potential regulatory liability.

### VII. Localisation & Internationalisation (L10n/i18n)

The application MUST be built with internationalisation from inception;
retroactive localisation of a shipped product is prohibited.

- All user-facing strings in the Flutter app MUST be externalised using ARB
  files; hardcoded string literals in widget or UI code are prohibited.
- The Flutter application MUST use `flutter_localizations` and `intl` as the
  canonical i18n stack. These packages MUST be listed in `pubspec.yaml` from
  project initialisation.
- Locale detection MUST default to the device locale at launch; the user MUST
  be able to override the locale within app settings without restarting the app.
- Date, time, number, and currency formatting MUST use locale-aware APIs
  (e.g., `DateFormat`, `NumberFormat` from the `intl` package); hardcoded
  format strings are prohibited.
- Right-to-left (RTL) layout MUST be supported using Flutter's built-in
  directionality system (`Directionality`, `TextDirection`); manually
  hard-coded LTR layout is prohibited.
- The backend API MUST accept and honour the `Accept-Language` HTTP header for
  all locale-sensitive responses (error messages, notification content,
  server-rendered text). Responses MUST fall back to `en` when the requested
  locale is unsupported.
- Translation resource files MUST be co-located under `mobile/lib/l10n/` and
  MUST be committed in the same PR as any new user-facing string.
- CI MUST validate that all ARB string references resolve in at least the
  default locale (`en`); untranslated strings that render as raw keys are a
  blocking defect.
- New locales MUST be introduced through the ARB workflow; ad-hoc string
  additions outside the l10n pipeline are prohibited.

**Rationale**: Echo targets a global audience. Embedding l10n/i18n into the
foundation prevents the significantly higher cost of retrofitting it into a
shipped product, and ensures RTL language support, locale-sensitive formatting,
and consistent copy management are correct from day one.

### VIII. Clean Architecture

All applications (backend and mobile) MUST be structured according to Clean
Architecture principles. The Dependency Rule is non-negotiable: source code
dependencies MUST only point inward; outer layers depend on inner layers,
never the reverse.

**Layers (inner to outer)**:

1. **Domain** (innermost): Pure business entities and value objects. MUST have
   zero dependencies on frameworks, databases, HTTP, or UI libraries. This
   layer is the stability anchor of the codebase.
2. **Application**: Use cases that orchestrate domain logic. MUST only import
   from the domain layer. Interfaces (ports) for all external concerns
   (persistence, messaging, notifications) MUST be defined here as abstract
   base classes or protocols; concrete implementations are prohibited in this
   layer.
3. **Adapters**: Implementations of application-layer interfaces — FastAPI
   route handlers and SQLAlchemy repository implementations (backend); Flutter
   widgets, state managers, and repository implementations (mobile). MUST NOT
   contain business logic; adapters translate between use-case data structures
   and external formats only.
4. **Infrastructure** (outermost): Framework wiring, database engine and
   session management, external API clients, environment configuration. MUST
   be isolated behind adapter interfaces so it can be swapped without touching
   inner layers.

**Backend (Python/FastAPI) mandatory package layout**:

```text
backend/src/
├── domain/                 # Entities, value objects — zero external dependencies
├── application/
│   ├── use_cases/          # Individual use case classes
│   └── ports/              # Abstract interfaces (repository contracts, service ports)
├── adapters/               # FastAPI routers, SQLAlchemy repository implementations
└── infrastructure/         # DB engine/session, settings, external API clients
```

**Mobile (Flutter) mandatory per-feature layout**:

```text
mobile/lib/features/[feature]/
├── domain/
│   ├── entities/           # Domain entities and value objects
│   ├── use_cases/          # Use case classes
│   └── ports/              # Repository and service interfaces
├── data/                   # Repository implementations, remote/local data sources
└── presentation/           # Widgets, view models, state management
```

- Business logic MUST NOT appear in FastAPI route handlers, widget `build()`
  methods, or ORM model methods. All logic MUST reside in use cases or domain
  entities.
- Cross-layer import violations (e.g., domain importing from adapters) MUST
  be caught automatically in CI. Backend: enforce via `ruff` import-boundary
  rules or a dedicated layer-linting step. Mobile: enforce via `dart analyze`
  package-level import constraints.
- Shared cross-feature domain concepts MUST reside in a dedicated
  `core/domain/` package; feature-specific domain code MUST NOT be imported
  across features.
- The `shared/` directory at the monorepo root MUST contain only
  cross-concern artifacts (OpenAPI schema, proto definitions if adopted) that
  do not belong to any single application's domain.

**Rationale**: Clean Architecture makes business rules testable in isolation
without spinning up HTTP servers or databases, decouples the domain from
framework churn (FastAPI upgrades, state-management library changes), and
creates a navigable codebase as the team and feature set grow. The Dependency
Rule prevents spaghetti imports and makes large-scale refactoring safe.

## Tech Stack & Monorepo Structure

This section defines the canonical technology choices and repository layout.
Deviations require an amendment to this constitution.

**Backend**: Python 3.13+, FastAPI, SQLAlchemy (async), Alembic (migrations),
pytest, `black` + `ruff` + `isort`. Dependency and virtual environment
management MUST use `uv`; direct invocation of `pip`, `pip-tools`, `venv`,
or `virtualenv` as the project toolchain is prohibited.

**Mobile**: Flutter 3.x (stable channel), Dart — targeting **Android (API 26+)**
and **iOS (iOS 14+)**. Required packages: `flutter_secure_storage`,
`flutter_localizations`, `intl`, `flutter_test` + `integration_test`.

**Admin Web**: React 19 + TypeScript + Vite for a browser-based internal admin
SPA. Required packages and tools: React Router, TanStack Query, React Hook
Form, Zod, Tailwind CSS, shadcn/ui, Biome, Vitest, React Testing Library, and
Playwright.

**Monorepo layout**:

```text
/
├── backend/              # FastAPI application (Clean Architecture)
│   ├── src/
│   │   ├── domain/           # Entities, value objects (zero external deps)
│   │   ├── application/
│   │   │   ├── use_cases/    # Individual use case classes
│   │   │   └── ports/        # Abstract interfaces (repos, service ports)
│   │   ├── adapters/         # FastAPI routers, repository implementations
│   │   └── infrastructure/   # DB engine, settings, external clients
│   └── tests/
│       ├── contract/
│       ├── integration/
│       └── unit/
├── admin/                # Internal admin SPA (React + TypeScript + Vite)
│   ├── src/
│   │   ├── app/
│   │   ├── core/
│   │   ├── features/
│   │   └── shared/
│   └── tests/
│       ├── unit/
│       ├── component/
│       └── e2e/
├── mobile/               # Flutter application (Android + iOS)
│   ├── lib/
│   │   ├── features/
│   │   │   └── [feature]/
│   │   │       ├── domain/
│   │   │       │   ├── entities/     # Domain entities and value objects
│   │   │       │   ├── use_cases/    # Use case classes
│   │   │       │   └── ports/        # Repository and service interfaces
│   │   │       ├── data/             # Repository impls, data sources
│   │   │       └── presentation/     # Widgets, view models, state
│   │   ├── shared/       # Design tokens, shared widgets
│   │   ├── l10n/         # ARB translation files (en.arb + locales)
│   │   └── core/         # Auth client, routing, cross-feature domain
│   └── test/
│       ├── widget/
│       ├── integration/
│       └── golden/
├── shared/               # Cross-concern artifacts (OpenAPI schema, proto)
├── specs/                # Feature specifications and plans
└── docs/                 # Architecture documentation
```

- Python dependencies MUST be managed with `uv`. All dependencies MUST be
  declared in `pyproject.toml` and locked in `uv.lock`; `uv.lock` MUST be
  committed. Direct `pip install` and manual `requirements.txt` maintenance
  are prohibited.
- Flutter dependencies MUST be pinned with exact versions in `pubspec.yaml`;
  `pubspec.lock` MUST be committed.
- Each sub-project (`backend/`, `admin/`, `mobile/`) MUST be independently buildable
  and testable from its own directory.

## Development Workflow & Quality Gates

The following gates MUST pass before any PR is merged to `main`:

1. **Linting & Formatting**: Zero errors from `ruff`, `black --check`,
   `isort --check`, `biome check`, `tsc --noEmit`, and `flutter analyze`.
2. **Test Suite**: All tests pass; backend coverage ≥80% enforced.
3. **OpenAPI Schema**: If API endpoints changed, the committed schema diff is
   reviewed and approved.
4. **Security Scan**: No secrets detected by the CI secret scanner.
5. **L10n Validation**: All ARB string references resolve in the `en` locale;
   no raw-key fallbacks in UI.
6. **Architecture Boundaries**: CI MUST confirm no cross-layer dependency
   violations (Principle VIII). Any violation is a blocking defect.
7. **Peer Review**: At least one reviewer other than the author has approved.

**Branch strategy**: Feature branches MUST follow the `NNN-short-name`
convention (managed by speckit). Direct commits to `main` are prohibited.

**Commit discipline**: Each commit MUST be atomic (one logical change) and
MUST reference the task ID (e.g., `T014`) in the commit message.

## Governance

This constitution supersedes all other development practices, style guides, and
informal agreements. When a conflict exists between this document and any other
guideline, this constitution takes precedence.

**Amendment procedure**:
1. Open a PR with the proposed change to `.specify/memory/constitution.md`.
2. Include a rationale section explaining the problem the amendment solves.
3. If the amendment removes or redefines a principle, include a migration plan
   for existing code and open tracking issues.
4. Require approval from at least two team members.
5. Increment the version per the versioning policy below.
6. Run the `/speckit.constitution` command to propagate changes to templates.

**Versioning policy**:
- **MAJOR**: Backward-incompatible changes — principle removals, redefinitions
  that invalidate prior compliance (e.g., changing mandatory test coverage
  downward, removing a security requirement).
- **MINOR**: Additive changes — new principle, new mandatory section, material
  expansion of guidance that requires new work.
- **PATCH**: Non-breaking refinements — clarifications, wording improvements,
  typo fixes, examples added.

**Compliance review**: All PRs MUST verify compliance with this constitution.
Complexity deviations from any principle MUST be documented in the
`Complexity Tracking` table in the relevant `plan.md` with justification.

**Version**: 1.4.0 | **Ratified**: 2026-02-25 | **Last Amended**: 2026-03-17