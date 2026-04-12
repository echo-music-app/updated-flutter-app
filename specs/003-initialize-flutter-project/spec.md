# Feature Spec: Initialize Flutter Project

**Branch**: `003-initialize-flutter-project`
**Date**: 2026-02-28

## Overview

Initialize the Flutter application within the existing monorepo, targeting Android (API 26+), iOS (iOS 14+), and Web (modern evergreen browsers). The project must comply with the Echo constitution's requirements for Dart/Flutter code quality, localisation, and testing. Additionally, set up a GitHub Actions CI pipeline to build the app for all three platforms.

## Clarifications

### Session 2026-02-28

- Q: Should Flutter Web be added as a target platform alongside Android and iOS? → A: Yes — add web as a third Flutter target (Android, iOS, Web).
- Q: How should `flutter_secure_storage` web security limitations be handled? → A: Add `flutter_secure_storage_web` as the web companion package; document `localStorage` limitation; defer auth-specific web token handling to the auth feature.

## Requirements

### Functional Requirements

1. A Flutter 3.x (stable channel) project exists at `mobile/` in the monorepo root.
2. The app targets **Android API 26+**, **iOS 14+**, and **Web (modern evergreen browsers — Chrome, Firefox, Safari, Edge)**.
3. Required packages are installed and pinned in `pubspec.yaml`:
   - `flutter_secure_storage` + `flutter_secure_storage_web` (web companion; uses `localStorage` — hardware-backed storage unavailable on web; auth-specific token handling deferred to the auth feature)
   - `flutter_localizations` (SDK package)
   - `intl`
   - `flutter_test` (SDK dev package)
   - `integration_test` (SDK dev package)
4. A shared design token package is defined under `mobile/lib/shared/` (colors, typography, spacing).
5. ARB-based localisation is configured with `flutter_localizations` and `intl`:
   - `mobile/lib/l10n/` contains at least `en.arb`
   - `l10n.yaml` is present and configured for `gen_l10n`
6. The app's directory structure follows the constitution layout:
   ```
   mobile/lib/
   ├── features/
   ├── shared/       # Design tokens, widgets
   ├── l10n/         # ARB files
   └── core/         # Auth client, routing
   ```
7. A placeholder home screen exists that demonstrates light/dark mode support, loading/empty/error states, and an accessible widget with `Semantics`.
8. The Flutter project is initialised with `--platforms android,ios,web` so all three platforms are scaffolded.

### CI Pipeline Requirements

9. A GitHub Actions workflow at `.github/workflows/flutter-ci.yml` runs on every PR and push to `main`.
10. The pipeline:
    - Runs `flutter analyze` (zero warnings/errors enforced)
    - Runs `dart format --output=none --set-exit-if-changed .` (formatting check)
    - Runs `flutter test` (widget tests)
    - Validates ARB references resolve in the `en` locale
    - Builds Android APK (debug) to verify compilation
    - Builds iOS (without code signing) to verify compilation
    - Builds Web (`flutter build web`) to verify compilation

## Non-Functional Requirements

- Code MUST pass `flutter analyze` and `dart format` with zero errors (constitution §I).
- Widget tests MUST cover the placeholder home screen (constitution §II).
- All user-facing strings MUST be externalised in ARB files (constitution §VII).
- `pubspec.lock` MUST be committed (constitution §Tech Stack).
- The project MUST be independently buildable from `mobile/` (constitution §Tech Stack).
- Web build MUST complete without errors; web-incompatible APIs (e.g., `flutter_secure_storage` native implementation) MUST use the web-compatible variant or a conditional import.

## Out of Scope

- Authentication flows (future feature)
- Real screens beyond the placeholder
- App store submission / code signing
- Backend integration
- PWA manifest customisation / service worker configuration (deferred to a future feature)