# Data Model: Initialize Flutter Project

> This feature is a project scaffolding/infrastructure feature. There are no persistent domain entities or database
> models. This document captures the configuration artifacts and file-system contracts that constitute the "model" for
> this feature.

## Configuration Artifacts

### `pubspec.yaml`

The Flutter package manifest. Defines dependencies, assets, and code generation settings.

| Field              | Value              |
|--------------------|--------------------|
| `name`             | `echo`             |
| `version`          | `1.0.0+1`          |
| `environment.sdk`  | `'>=3.3.0 <4.0.0'` |
| `flutter.generate` | `true`             |

**Required dependencies:**

| Package                  | Type           | Constraint     | Notes                                     |
|--------------------------|----------------|----------------|-------------------------------------------|
| `flutter`                | dependency     | `sdk: flutter` |                                           |
| `flutter_localizations`  | dependency     | `sdk: flutter` |                                           |
| `intl`                   | dependency     | `^0.19.0`      |                                           |
| `flutter_secure_storage` | dependency     | `^9.2.2`       | Includes web federated impl automatically |
| `flutter_test`           | dev_dependency | `sdk: flutter` |                                           |
| `integration_test`       | dev_dependency | `sdk: flutter` |                                           |
| `flutter_lints`          | dev_dependency | `^4.0.0`       |                                           |

### `l10n.yaml`

ARB localisation configuration for `gen_l10n`.

| Field                      | Value                    |
|----------------------------|--------------------------|
| `arb-dir`                  | `lib/l10n`               |
| `template-arb-file`        | `app_en.arb`             |
| `output-localization-file` | `app_localizations.dart` |
| `output-class`             | `AppLocalizations`       |
| `output-dir`               | `lib/generated/l10n`     |
| `synthetic-package`        | `false`                  |
| `nullable-getter`          | `false`                  |

### `analysis_options.yaml`

Lint configuration.

| Field     | Value                                |
|-----------|--------------------------------------|
| `include` | `package:flutter_lints/flutter.yaml` |

## Design Token Schema

The `mobile/lib/shared/design/` package defines compile-time constants (no runtime model). These are Dart classes, not
database entities.

### `AppColors`

| Token       | Type    | Description             |
|-------------|---------|-------------------------|
| `primary`   | `Color` | Brand primary color     |
| `onPrimary` | `Color` | Text/icon on primary    |
| `surface`   | `Color` | Card/surface background |
| `onSurface` | `Color` | Text/icon on surface    |
| `error`     | `Color` | Error state color       |
| `onError`   | `Color` | Text/icon on error      |

Both light and dark variants are defined in `AppTheme.light` and `AppTheme.dark`.

### `AppTypography`

| Token            | Type        | Description         |
|------------------|-------------|---------------------|
| `headlineLarge`  | `TextStyle` | Large headlines     |
| `headlineMedium` | `TextStyle` | Section headers     |
| `bodyLarge`      | `TextStyle` | Primary body text   |
| `bodyMedium`     | `TextStyle` | Secondary body text |
| `labelLarge`     | `TextStyle` | Button labels       |

### `AppSpacing`

| Token | Type     | Value |
|-------|----------|-------|
| `xs`  | `double` | 4.0   |
| `sm`  | `double` | 8.0   |
| `md`  | `double` | 16.0  |
| `lg`  | `double` | 24.0  |
| `xl`  | `double` | 32.0  |

## Localisation Schema

### `lib/l10n/app_en.arb` (template)

Initial keys required for the placeholder home screen:

| Key              | Default (en)           | Description           |
|------------------|------------------------|-----------------------|
| `appTitle`       | `Echo`                 | App name in title bar |
| `homeTitle`      | `Home`                 | Home screen title     |
| `loadingMessage` | `Loading...`           | Generic loading text  |
| `emptyMessage`   | `Nothing here yet`     | Empty state text      |
| `errorMessage`   | `Something went wrong` | Generic error text    |
| `retryButton`    | `Retry`                | Retry button label    |

## Directory Layout

```text
mobile/
├── android/
│   └── app/build.gradle.kts        # minSdk=26, compileSdk=35, targetSdk=35
├── ios/
│   └── Runner.xcodeproj/           # IPHONEOS_DEPLOYMENT_TARGET=14.0
├── web/                            # Flutter web scaffold
│   ├── index.html                  # Entry point (base href="/")
│   ├── manifest.json               # PWA manifest (name from pubspec; not customised)
│   ├── favicon.png
│   └── icons/                      # Placeholder PWA icons
├── lib/
│   ├── main.dart                   # App entry point
│   ├── app.dart                    # MaterialApp with l10n, theme, routing
│   ├── core/
│   │   └── routing/
│   │       └── app_router.dart     # Route definitions (placeholder)
│   ├── features/
│   │   └── home/
│   │       └── home_screen.dart    # Placeholder screen (loading/empty/error/data)
│   ├── shared/
│   │   └── design/
│   │       ├── app_colors.dart
│   │       ├── app_typography.dart
│   │       ├── app_spacing.dart
│   │       └── app_theme.dart
│   ├── l10n/
│   │   └── app_en.arb
│   └── generated/
│       └── l10n/                   # gen_l10n output (gitignored)
├── test/
│   ├── widget/
│   │   └── home_screen_test.dart   # Widget tests (loading/empty/error/data states)
│   └── goldens/                    # Golden PNG files (committed, binary)
├── integration_test/
│   └── app_test.dart               # Placeholder integration test
├── l10n.yaml
├── analysis_options.yaml
└── pubspec.yaml
```