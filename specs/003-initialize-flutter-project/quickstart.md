# Quickstart: Initialize Flutter Project

## Prerequisites

- Flutter 3.x stable channel installed (`flutter --version`)
- Android SDK with API 35 (Android Studio or `sdkmanager`)
- Xcode 15+ (macOS only, for iOS builds)
- Chrome browser (for web development)
- An Android emulator, iOS simulator, or Chrome for running the app

## First-Time Setup

```bash
# From repo root — install Flutter deps
cd mobile
flutter config --enable-web   # enable web platform (once per installation)
flutter pub get

# Verify setup
flutter doctor
flutter analyze
```

## Running the App

```bash
# From mobile/
flutter run                    # interactive device selection
flutter run -d emulator-5554   # specific Android emulator
flutter run -d "iPhone 15"     # specific iOS simulator (macOS only)
flutter run -d chrome          # web (opens Chrome)
flutter run -d web-server      # web (headless server, useful for debugging)
```

## Running Tests

```bash
# From mobile/
flutter test                           # all widget/unit tests (Dart VM)
flutter test test/widget/              # widget tests only
flutter test --update-goldens          # update golden files (local only)
flutter test integration_test/         # integration tests (requires running device)

# Web-specific tests (only needed when web-specific behavior exists):
flutter test --platform chrome         # run widget tests in headless Chrome
```

## Linting & Formatting

```bash
# From mobile/
dart format .                          # auto-format all Dart files
dart format --output=none --set-exit-if-changed .  # CI format check
flutter analyze                        # static analysis (zero errors required)
```

## Localisation

```bash
# From mobile/ — regenerate localisation code after editing ARB files
flutter gen-l10n

# ARB files live at:
#   mobile/lib/l10n/app_en.arb   (template — edit this to add strings)
# Generated code at:
#   mobile/lib/generated/l10n/   (do not edit manually; gitignored)
```

To add a new user-facing string:
1. Add the key+value to `lib/l10n/app_en.arb`
2. Run `flutter gen-l10n` (or `flutter pub get` with `generate: true`)
3. Use `AppLocalizations.of(context)!.myKey` in widget code

## Design Tokens

All colors, typography, and spacing are defined in `lib/shared/design/`:

```dart
// Colors
AppColors.primary
AppColors.surface

// Typography
AppTypography.headlineLarge
AppTypography.bodyMedium

// Spacing
AppSpacing.md  // 16.0
```

Never use hardcoded hex colors or pixel values in widget code.

## Web Builds

```bash
# From mobile/
flutter build web --release --web-renderer canvaskit

# Output: mobile/build/web/
# Serve locally to test the production build:
cd build/web && python3 -m http.server 8080
```

**Note on `flutter_secure_storage` on web**: The web implementation uses AES-GCM encryption via the Web Crypto API, with both key and ciphertext stored in `localStorage`. This is weaker than native Keystore/Keychain — there is no hardware-backed key storage. Tokens stored in web `localStorage` are also cleared if the user clears site data or uses private mode. Auth-specific web token handling is deferred to the auth feature.

## CI Pipeline

The GitHub Actions workflow at `.github/workflows/flutter-ci.yml` runs automatically on PR and push to `main` for changes under `mobile/**`. Jobs:

| Job | Runner | What it does |
|---|---|---|
| `analyze` | ubuntu-latest | Format check, static analysis, widget tests |
| `build-android` | ubuntu-latest | Builds debug APK |
| `build-ios` | macos-14 | Builds unsigned IPA |
| `build-web` | ubuntu-latest | Builds web (CanvasKit, release) |

To run the equivalent checks locally before pushing:

```bash
cd mobile
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug                            # Android
flutter build ipa --no-codesign                      # iOS (macOS only)
flutter build web --release --web-renderer canvaskit # Web
```

## Project Structure

```text
mobile/
├── lib/
│   ├── main.dart           # Entry point
│   ├── app.dart            # MaterialApp (theme, l10n, routing)
│   ├── core/routing/       # App router
│   ├── features/home/      # Placeholder home screen
│   ├── shared/design/      # Design tokens (colors, typography, spacing)
│   ├── l10n/               # ARB translation files
│   └── generated/l10n/     # gen_l10n output (gitignored)
├── web/                    # Flutter web scaffold
├── test/widget/            # Widget tests
├── test/goldens/           # Golden PNG files
└── integration_test/       # Integration tests
```

## Navigation Patterns

- **Back behavior**: system back button / `Navigator.pop(context)`
- **Deep links**: not configured in this phase
- **Modal presentation**: `showDialog` / `showModalBottomSheet` for overlays
- **Web routing**: Flutter web uses the hash-based router by default; path-based routing (with `url_strategy` package) is deferred to a future feature

All navigation is explicit — routes are defined in `core/routing/app_router.dart`.