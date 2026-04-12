# Tasks: Initialize Flutter Project

**Input**: Design documents from `/specs/003-initialize-flutter-project/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: Widget tests are included per constitution §II (test-first discipline).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2)
- Include exact file paths in descriptions

## User Stories

| ID  | Priority | Title                    | Description                                                                                                                  |
|-----|----------|--------------------------|------------------------------------------------------------------------------------------------------------------------------|
| US1 | P1       | Flutter Project Scaffold | Initialize the Flutter project, configure all three platforms, packages, design tokens, localisation, and placeholder screen |
| US2 | P1       | CI Pipeline              | GitHub Actions workflow that lints, tests, and builds for Android, iOS, and Web                                              |

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the Flutter project scaffolded for all three platforms and wire it into the monorepo

- [x] T001 Initialize Flutter project at `mobile/` via
  `flutter create --org com.echo.app --platforms android,ios,web mobile` from repo root
- [x] T002 Update `mobile/android/app/build.gradle.kts`: set `namespace="com.echo.app"`, `compileSdk=35`, `minSdk=26`,
  `targetSdk=35`
- [x] T003 Set iOS deployment target to `14.0` in `mobile/ios/Runner.xcodeproj/project.pbxproj` for all three build
  configurations (Debug, Release, Profile) by replacing `IPHONEOS_DEPLOYMENT_TARGET = 11.0` (or current default) with
  `IPHONEOS_DEPLOYMENT_TARGET = 14.0`
- [x] T004 Replace generated `mobile/pubspec.yaml` dependencies section: add `flutter_localizations` (sdk: flutter),
  `intl: ^0.20.2`, `flutter_secure_storage: ^10.0.0`; add dev deps `flutter_lints: ^4.0.0`; set `generate: true` under
  the `flutter:` key
- [x] T005 Add `NSFaceIDUsageDescription` key with value `"This app uses Face ID to securely store credentials."` to
  `mobile/ios/Runner/Info.plist`
- [x] T006 Run `flutter pub get` from `mobile/` and commit resulting `mobile/pubspec.lock`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure required before user story implementation can begin

**⚠️ CRITICAL**: Phase 1 must be complete. Both US1 and US2 depend on this phase.

- [x] T007 Create `mobile/analysis_options.yaml` with content: `include: package:flutter_lints/flutter.yaml`
- [x] T008 Create `mobile/l10n.yaml` with fields: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`,
  `output-localization-file: app_localizations.dart`, `output-class: AppLocalizations`,
  `output-dir: lib/generated/l10n`, `synthetic-package: false`, `nullable-getter: false`
- [x] T009 Create `mobile/lib/l10n/app_en.arb` with keys: `appTitle` ("Echo"), `homeTitle` ("Home"), `loadingMessage` ("
  Loading..."), `emptyMessage` ("Nothing here yet"), `errorMessage` ("Something went wrong"), `retryButton` ("Retry")
- [x] T010 Add `mobile/lib/generated/` to `mobile/.gitignore`; add `test/goldens/*.png binary` to repo-root
  `.gitattributes`
- [x] T011 Create directory stubs: `mobile/lib/features/`, `mobile/lib/core/routing/`, `mobile/lib/shared/design/`,
  `mobile/test/widget/`, `mobile/test/goldens/`, `mobile/integration_test/`

**Checkpoint**: Foundation ready — US1 and US2 can begin

---

## Phase 3: User Story 1 — Flutter Project Scaffold (Priority: P1) 🎯 MVP

**Goal**: A buildable Flutter app for Android, iOS, and Web with design tokens, ARB localisation, and a placeholder home
screen handling loading/empty/error/data states with light and dark theme support.

**Independent Test**: `flutter analyze` passes with zero warnings; `flutter test test/widget/` passes; app runs on an
Android emulator, iOS simulator, and `flutter run -d chrome` showing the home screen.

### Tests for User Story 1

> **Write these FIRST — they must FAIL before implementation begins**

- [x] T012 [P] [US1] Create `mobile/test/widget/home_screen_test.dart` with `testWidgets` cases for: loading state
  renders `CircularProgressIndicator`, empty state renders `emptyMessage` string, error state renders `errorMessage`
  text and a retry `ElevatedButton`, data state renders `homeTitle` — all using `AppLocalizations` and `AppTheme`
- [x] T013 [P] [US1] Create `mobile/test/widget/app_theme_test.dart` verifying `AppTheme.light` and `AppTheme.dark`
  expose non-null `primaryColor`, and that `AppColors`, `AppTypography`, `AppSpacing` constants are defined and non-null

### Implementation for User Story 1

- [x] T014 [P] [US1] Create `mobile/lib/shared/design/app_colors.dart` defining `AppColors` class with static `Color`
  constants: `primary`, `onPrimary`, `surface`, `onSurface`, `error`, `onError` (define light-theme values inline)
- [x] T015 [P] [US1] Create `mobile/lib/shared/design/app_typography.dart` defining `AppTypography` class with static
  `TextStyle` constants: `headlineLarge`, `headlineMedium`, `bodyLarge`, `bodyMedium`, `labelLarge`
- [x] T016 [P] [US1] Create `mobile/lib/shared/design/app_spacing.dart` defining `AppSpacing` class with static `double`
  constants: `xs=4.0`, `sm=8.0`, `md=16.0`, `lg=24.0`, `xl=32.0`
- [x] T017 [US1] Create `mobile/lib/shared/design/app_theme.dart` defining `AppTheme` class with static getters
  `ThemeData get light` and `ThemeData get dark`, both built using `AppColors` and `AppTypography` tokens (depends on
  T014, T015, T016)
- [x] T018 [US1] Create `mobile/lib/core/routing/app_router.dart` defining route name constants (`homeRoute = '/'`) and
  a `static Route<dynamic> generateRoute(RouteSettings settings)` function returning `MaterialPageRoute` for `/` (
  HomeScreen) and a 404 fallback
- [x] T019 [US1] Create `mobile/lib/features/home/home_screen.dart` implementing `HomeScreen` as a `StatelessWidget`
  accepting a `HomeScreenState state` enum parameter (`loading`, `empty`, `error`, `data`); renders:
  `CircularProgressIndicator` for loading; `Text(AppLocalizations.of(context)!.emptyMessage)` for empty; a `Column` with
  `Text(errorMessage)` and `ElevatedButton(onPressed: null, child: Text(retryButton))` wrapped in
  `Semantics(label: retryButton)` for error; `Text(homeTitle)` for data; uses only `AppColors` and `AppSpacing` tokens —
  no hardcoded hex or pixel values
- [x] T020 [US1] Create `mobile/lib/app.dart` implementing `EchoApp` as a `StatelessWidget` returning `MaterialApp`
  with: `localizationsDelegates: AppLocalizations.localizationsDelegates`,
  `supportedLocales: AppLocalizations.supportedLocales`, `theme: AppTheme.light`, `darkTheme: AppTheme.dark`,
  `onGenerateRoute: AppRouter.generateRoute`
- [x] T021 [US1] Replace generated `mobile/lib/main.dart` with:
  `import 'app.dart'; void main() => runApp(const EchoApp());`
- [x] T022 [US1] Run `flutter gen-l10n` from `mobile/` to generate `lib/generated/l10n/app_localizations.dart`; verify
  exit code 0
- [x] T023 [US1] Run `flutter analyze` from `mobile/`; fix any warnings or errors until output is clean (zero issues)
- [x] T024 [US1] Run `dart format .` from `mobile/` to auto-format all Dart files
- [x] T025 [US1] Run `flutter test test/widget/` from `mobile/`; confirm T012 and T013 pass

**Checkpoint**: US1 complete — `flutter run -d chrome`, `flutter run -d emulator`, and `flutter test` all succeed.

---

## Phase 4: User Story 2 — CI Pipeline (Priority: P1)

**Goal**: A GitHub Actions workflow enforcing code quality and confirming the app compiles for Android, iOS, and Web on
every PR and push to `main`.

**Independent Test**: Push to a PR branch touching `mobile/`; all four CI jobs (`analyze`, `build-android`, `build-ios`,
`build-web`) pass in GitHub Actions.

### Implementation for User Story 2

- [x] T026 [US2] Create `.github/workflows/flutter-ci.yml` with top-level `name: Mobile CI` and trigger block:
  `on: push: branches: [main] paths: ['mobile/**', '.github/workflows/flutter-ci.yml']` and
  `pull_request: paths: ['mobile/**', '.github/workflows/flutter-ci.yml']`
- [x] T027 [US2] Add `analyze` job to `.github/workflows/flutter-ci.yml` (runner: `ubuntu-latest`,
  `defaults.run.working-directory: mobile`): steps — `actions/checkout@v6`, `subosito/flutter-action@v2` with
  `flutter-version: '3.x'`, `channel: stable`, `cache: true`, then `flutter config --enable-web`, `flutter pub get`,
  `dart format --output=none --set-exit-if-changed .`, `flutter analyze --no-pub`, `flutter test --no-pub`
- [x] T028 [US2] Add `build-android` job (runner: `ubuntu-latest`, `needs: [analyze]`,
  `defaults.run.working-directory: mobile`): steps — `actions/checkout@v6`, `actions/setup-java@v4` with
  `distribution: temurin` and `java-version: '17'`, `subosito/flutter-action@v2` (same settings), `flutter pub get`,
  `flutter build apk --debug`, `actions/upload-artifact@v4` uploading path
  `mobile/build/app/outputs/flutter-apk/app-debug.apk` as artifact name `android-debug-apk`
- [x] T029 [US2] Add `build-ios` job (runner: `macos-14`, `needs: [analyze]`, `defaults.run.working-directory: mobile`):
  steps — `actions/checkout@v6`, `subosito/flutter-action@v2` (same settings), `flutter pub get`,
  `flutter build ipa --no-codesign`, `actions/upload-artifact@v4` uploading path `mobile/build/ios/ipa/*.ipa` as
  artifact name `ios-unsigned-ipa`
- [x] T030 [US2] Add `build-web` job (runner: `ubuntu-latest`, `needs: [analyze]`,
  `defaults.run.working-directory: mobile`): steps — `actions/checkout@v6`, `subosito/flutter-action@v2` (same
  settings), `flutter config --enable-web`, `flutter pub get`, `flutter build web --release --web-renderer canvaskit`,
  `actions/upload-artifact@v4` uploading path `mobile/build/web/` as artifact name `web-build`
- [x] T031 [US2] Validate YAML syntax of `.github/workflows/flutter-ci.yml` by running
  `python3 -c "import yaml, sys; yaml.safe_load(open('.github/workflows/flutter-ci.yml'))" && echo OK` from repo root

**Checkpoint**: US2 complete — push to PR branch and confirm all four CI jobs pass.

---

## Phase 5: Polish & Cross-Cutting Concerns

**Purpose**: Integration test placeholder, cleanup, and final validation

- [x] T032 [P] Create `mobile/integration_test/app_test.dart` with a single smoke test:
  `testWidgets('app launches', (tester) async { app.main(); await tester.pumpAndSettle(); expect(find.byType(MaterialApp), findsOneWidget); })`
- [x] T033 [P] Delete `mobile/test/widget_test.dart` (Flutter-generated counter example test, replaced by `test/widget/`
  structure from T012); verify no other generated boilerplate test files remain
- [x] T034 [P] Append Flutter-specific patterns to repo-root `.gitignore`: `mobile/.dart_tool/`, `mobile/build/`,
  `mobile/*.g.dart`, `mobile/*.freezed.dart` (if not already present from `flutter create` output)
- [x] T035 Run full local validation from `mobile/`:
  `flutter config --enable-web && flutter pub get && flutter gen-l10n && dart format --output=none --set-exit-if-changed . && flutter analyze && flutter test` —
  all commands must exit 0

---

## Dependencies

```
T001 → T002, T003, T004, T005
T004 → T006
T006 → T007, T008, T009, T010, T011  (Phase 2 — needs pub get done)
T011 → T012..T025  (US1 can start)
T011 → T026..T031  (US2 can start independently of US1)

Within US1:
  T012, T013 (tests) parallel with T014, T015, T016 (tokens — separate files)
  T014 + T015 + T016 → T017 (AppTheme needs all 3 token files)
  T017 + T018 + T019 → T020 (app.dart needs theme + router + screen)
  T020 → T021 (main.dart needs EchoApp)
  T021 → T022 → T023 → T024 → T025 (sequential quality gates)

Within US2:
  T026 → T027 → T028, T029, T030 (jobs added to same file sequentially)
  T028, T029, T030 → T031 (validate after all jobs present)

Phase 5:
  T032, T033, T034 are all parallel (different files)
  T032 + T033 + T034 → T035 (final validation runs last)
```

## Parallel Execution

**Within US1** (after T011):

- T012, T013 (test files), T014 (AppColors), T015 (AppTypography), T016 (AppSpacing) — all 5 tasks can be written in
  parallel (separate files, no dependencies between them)
- T017 (AppTheme) and T018 (AppRouter) can be written in parallel after T014+T015+T016
- T019 (HomeScreen) can be written in parallel with T017+T018

**US1 and US2 are fully independent** after Phase 2 — a second developer can work on the CI workflow while the first
implements the Flutter scaffold.

**Within Phase 5**: T032, T033, T034 all parallel.

## Implementation Strategy

**MVP scope**: Phase 1 + Phase 2 + Phase 3 (US1) = a buildable, analyzable, testable Flutter project for all three
platforms with design tokens, localisation, and a placeholder screen.

**Increment 2**: Phase 4 (US2) = CI pipeline including all three build jobs. Fully independent of US1 after Phase 2.

**Final**: Phase 5 = integration test stub and cleanup.

**Suggested delivery order** for a single developer: T001–T011 (linear setup), then T012–T025 (US1), then T026–T031 (
US2), then T032–T035 (polish).