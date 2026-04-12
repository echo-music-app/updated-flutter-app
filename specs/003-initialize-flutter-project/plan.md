# Implementation Plan: Initialize Flutter Project

**Branch**: `003-initialize-flutter-project` | **Date**: 2026-02-28 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/003-initialize-flutter-project/spec.md`

## Summary

Initialize the Flutter application at `mobile/` in the monorepo, targeting Android API 26+, iOS 14+, and Web (modern
evergreen browsers). Includes required packages (`flutter_localizations`, `intl`, `flutter_secure_storage`,
`flutter_test`, `integration_test`), ARB localisation setup, shared design tokens, a placeholder home screen with
light/dark mode and all three UI states, widget tests, and a GitHub Actions CI pipeline with four jobs: analyze+test,
build-android, build-ios, and build-web.

## Technical Context

**Language/Version**: Dart (Flutter 3.x stable channel)
**Primary Dependencies**: `flutter_localizations` (SDK), `intl ^0.19.0`, `flutter_secure_storage ^9.2.2` (web impl
included), `flutter_lints ^4.0.0`
**Storage**: N/A (no persistent storage in this feature)
**Testing**: `flutter_test` (SDK), `integration_test` (SDK), `matchesGoldenFile` for golden tests; default VM test
runner (no `--platform chrome` needed for scaffold)
**Target Platform**: Android API 26+ (minSdk=26, targetSdk=35), iOS 14+ (IPHONEOS_DEPLOYMENT_TARGET=14.0), Web (
CanvasKit renderer, modern evergreen browsers)
**Project Type**: Mobile + Web application (Flutter)
**Performance Goals**: App cold-start ≤3s on mid-range devices; 60 fps scroll (constitution §V)
**Constraints**: `flutter analyze` zero warnings; `dart format` clean; `pubspec.lock` committed; web build completes
without errors
**Scale/Scope**: Single placeholder screen; project scaffolding for future features

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle          | Status | Notes                                                                                                   |
|--------------------|--------|---------------------------------------------------------------------------------------------------------|
| §I Code Quality    | ✅ PASS | `dart format` + `flutter analyze` enforced in CI; `analysis_options.yaml` configured                    |
| §II Test-First     | ✅ PASS | Widget tests written for placeholder home screen; golden test scaffolding included                      |
| §III API Contract  | N/A    | No API endpoints in this feature                                                                        |
| §IV UX Consistency | ✅ PASS | Design tokens defined; light/dark mode; loading/empty/error states; `Semantics` widget                  |
| §V Performance     | ✅ PASS | No performance-sensitive code in scaffold; targets defined in spec                                      |
| §VI Security       | ✅ PASS | `flutter_secure_storage` included; web limitation documented; no hardcoded secrets                      |
| §VII L10n/i18n     | ✅ PASS | `flutter_localizations` + `intl` in `pubspec.yaml`; ARB files configured from inception                 |
| Tech Stack         | ✅ PASS | Flutter 3.x stable; Android API 26+; iOS 14+; Web; required packages included; `pubspec.lock` committed |
| Quality Gates      | ✅ PASS | All gates configured in CI pipeline (4 jobs)                                                            |

**No violations. No entries required in Complexity Tracking.**

## Project Structure

### Documentation (this feature)

```text
specs/003-initialize-flutter-project/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (repository root)

```text
mobile/                              # Flutter application (Android + iOS + Web)
├── android/
│   └── app/
│       └── build.gradle.kts        # minSdk=26, compileSdk=35, targetSdk=35
├── ios/
│   └── Runner.xcodeproj/           # IPHONEOS_DEPLOYMENT_TARGET=14.0
├── web/                            # Flutter web scaffold
│   ├── index.html                  # Entry point (base href="/")
│   ├── manifest.json               # PWA manifest (not customised in this feature)
│   ├── favicon.png
│   └── icons/                      # Placeholder PWA icons
├── lib/
│   ├── main.dart                   # App entry point
│   ├── app.dart                    # MaterialApp (l10n, theme, routing)
│   ├── core/
│   │   └── routing/
│   │       └── app_router.dart     # Route definitions (placeholder)
│   ├── features/
│   │   └── home/
│   │       └── home_screen.dart    # Placeholder screen (loading/empty/error/data)
│   ├── shared/
│   │   └── design/
│   │       ├── app_colors.dart     # Color tokens
│   │       ├── app_typography.dart # Text style tokens
│   │       ├── app_spacing.dart    # Spacing constants
│   │       └── app_theme.dart      # ThemeData (light + dark)
│   ├── l10n/
│   │   └── app_en.arb             # Template ARB (en locale)
│   └── generated/
│       └── l10n/                   # gen_l10n output (gitignored)
├── test/
│   ├── widget/
│   │   └── home_screen_test.dart   # Widget tests (loading/empty/error/data states)
│   └── goldens/                    # Golden PNG files (committed, binary)
├── integration_test/
│   └── app_test.dart               # Placeholder integration test
├── .github/workflows/
│   └── flutter-ci.yml              # CI: analyze+test + build-android + build-ios + build-web
├── l10n.yaml                       # gen_l10n config
├── analysis_options.yaml           # Lint rules
└── pubspec.yaml                    # Pinned deps; generate: true; pubspec.lock committed

.github/workflows/
└── flutter-ci.yml                  # Triggers on mobile/** changes
```

**Structure Decision**: Option 3 (Mobile + API) from the constitution monorepo layout, extended with a `web/` directory.
The `mobile/` directory is already designated in the constitution. No backend changes in this feature.

## Complexity Tracking

> No constitution violations in this feature.

## Implementation Notes

### Android Configuration

`android/app/build.gradle.kts` key settings:

```kotlin
android {
    namespace = "com.echo.app"
    compileSdk = 35
    defaultConfig {
        minSdk = 26
        targetSdk = 35
        versionCode = 1
        versionName = "1.0.0"
    }
}
```

### iOS Configuration

In Xcode project `Runner.xcodeproj`, set:

- `IPHONEOS_DEPLOYMENT_TARGET = 14.0` (all build configurations: Debug, Release, Profile)

### `flutter_secure_storage` iOS

Add to `ios/Runner/Info.plist`:

```xml

<key>NSFaceIDUsageDescription</key>
<string>This app uses Face ID to securely store credentials.</string>
```

### `flutter_secure_storage` Web

The `flutter_secure_storage ^9.x` package includes the web federated implementation automatically — no separate
`pubspec.yaml` entry for `flutter_secure_storage_web` is needed. On web, it uses AES-GCM encryption via the Web Crypto
API with both key and ciphertext stored in `localStorage`. There is no hardware-backed key storage on web; this
limitation is documented in the spec. Auth-specific web token handling is deferred to the auth feature.

### Web Platform

`flutter config --enable-web` must be run once per Flutter installation (including every CI runner) before any
`flutter build web` or `flutter run -d chrome` command.

Web renderer: use `--web-renderer canvaskit` explicitly for builds. The HTML renderer is on a deprecation track;
Wasm/Skwasm is not yet stable for general audiences.

`web/manifest.json` and PWA service worker are not customised in this feature (deferred per spec Out of Scope).

### Localisation Bootstrap

`lib/app.dart` must include:

```dart
MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: AppTheme.light,
  darkTheme: AppTheme.dark,
  home: const HomeScreen(),
)
```

### CI Workflow

`.github/workflows/flutter-ci.yml`:

- Trigger: `push` to `main` and `pull_request` — both filtered to `mobile/**` and `.github/workflows/flutter-ci.yml`
  paths
- `analyze` job (ubuntu-latest): `flutter config --enable-web` → `flutter pub get` →
  `dart format --output=none --set-exit-if-changed .` → `flutter analyze --no-pub` → `flutter test --no-pub`
- `build-android` job (ubuntu-latest, needs: analyze): Java 17 (temurin) → `flutter pub get` →
  `flutter build apk --debug` → upload APK artifact
- `build-ios` job (macos-14, needs: analyze): `flutter pub get` → `flutter build ipa --no-codesign` → upload IPA
  artifact
- `build-web` job (ubuntu-latest, needs: analyze): `flutter config --enable-web` → `flutter pub get` →
  `flutter build web --release --web-renderer canvaskit` → upload `build/web/` artifact

### Generated Files

`lib/generated/l10n/` — add to `.gitignore` and regenerate via `flutter pub get` (with `generate: true`) in every CI
step that runs the app or tests.

### Test Strategy

Default `flutter test` (Dart VM runner) is sufficient for all widget tests in this scaffold feature.
`flutter test --platform chrome` is not required until web-specific rendering behavior exists (e.g., `dart:html`
interop, `HtmlElementView`, canvas output validation).