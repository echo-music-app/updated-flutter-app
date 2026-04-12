# Research: Initialize Flutter Project

## Flutter Project Initialization

**Decision:** Use `flutter create --org com.echo.app --platforms android,ios,web mobile` from the repo root. Immediately set `minSdk = 26` in `android/app/build.gradle.kts` and iOS deployment target to `14.0` in Xcode project settings. The `web/` directory is scaffolded automatically.

**Rationale:** The constitution mandates Android API 26+ and iOS 14+. Web is now a required target per spec clarification. `minSdk = 26` enables hardware-backed Android Keystore (required by `flutter_secure_storage`), autofill, and biometric APIs. iOS 14 is the minimum Apple accepts for new submissions. Use Kotlin DSL (`build.gradle.kts`) as the current Flutter default.

**Alternatives considered:** `minSdk = 21` (Flutter historical default) — rejected because it blocks `flutter_secure_storage` v5+ (requires API 23+) and is below the project's stated target. Adding web retroactively via `flutter create --platforms web .` — works but creates `web/` after initial setup; doing it upfront with `--platforms android,ios,web` is cleaner.

---

## GitHub Actions CI Pipeline

**Decision:** Four-job pipeline in `.github/workflows/flutter-ci.yml`:
1. `analyze` job on `ubuntu-latest`: `dart format` check + `flutter analyze` + `flutter test`
2. `build-android` job on `ubuntu-latest` (needs: analyze): builds debug APK
3. `build-ios` job on `macos-14` (needs: analyze): builds unsigned IPA (`--no-codesign`)
4. `build-web` job on `ubuntu-latest` (needs: analyze): `flutter build web --release --web-renderer canvaskit`

Use `subosito/flutter-action@v2` with pinned `flutter-version: '3.x'` (latest stable). Cache `.pub-cache` using `pubspec.lock` hash. Trigger on pushes to `main` and PRs that touch `mobile/**`.

**Important:** `flutter config --enable-web` must be run once per CI Flutter installation before any web command. This is a one-line step added before `flutter pub get` in web-related jobs.

**Rationale:** Analyze/test on Ubuntu first (cheap) before spending macOS runner minutes. iOS build requires macOS runner with Xcode; `macos-14` (Apple Silicon) is ~2x faster than `macos-13` (Intel). `--no-codesign` for CI avoids certificate management complexity. Web builds run cheaply on Ubuntu. `--web-renderer canvaskit` is the current Flutter stable recommended renderer (HTML renderer is on a deprecation track; Wasm/Skwasm not yet stable for general use).

**Alternatives considered:**
- Running `flutter test --platform chrome` in CI: not needed for scaffold (VM test runner covers widget tests sufficiently; Chrome tests add fragility without benefit until web-specific behavior exists).
- Using `--wasm` for web build: not yet stable for general audiences (requires COOP/COEP headers, `SharedArrayBuffer` browser support).
- `macos-13` Intel runners: slower, will be deprecated.

---

## Package Requirements

**Decision:** Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.19.0
  flutter_secure_storage: ^9.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  integration_test:
    sdk: flutter
  flutter_lints: ^4.0.0
```

**No separate `flutter_secure_storage_web` entry needed** — `flutter_secure_storage ^9.x` includes the web federated implementation automatically. The web variant uses AES-GCM encryption via the Web Crypto API, with both key and ciphertext stored in `localStorage`. This provides encryption at rest but no hardware-backed key storage; the security guarantee is weaker than native Keystore/Keychain, and this limitation is documented in the spec.

**Rationale:**
- `flutter_localizations` and `intl`: official i18n stack required by constitution §VII.
- `flutter_secure_storage ^9.2.2`: uses Android Keystore (hardware-backed on API 26+), iOS Keychain, and Web Crypto+localStorage for web. The federated plugin system resolves the web implementation without an explicit `pubspec.yaml` entry.
- `integration_test`: official replacement for deprecated `flutter_driver`; runs on device/emulator.
- `flutter_lints`: Flutter team's recommended lint set, included by default in new projects.

**Alternatives considered:** `easy_localization` — simpler API but bypasses official toolchain. `patrol` for integration tests — excellent but adds complexity beyond project init scope. Explicit `flutter_secure_storage_web` pin — only needed if the web package version must be overridden independently of the main package.

---

## ARB Localisation Setup

**Decision:** Create `mobile/l10n.yaml` with `synthetic-package: false`. Store ARBs in `mobile/lib/l10n/`. Set `generate: true` in `pubspec.yaml`. Generated Dart code goes to `lib/generated/l10n/`.

```yaml
# l10n.yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
output-class: AppLocalizations
output-dir: lib/generated/l10n
synthetic-package: false
nullable-getter: false
```

**Rationale:** `synthetic-package: false` writes generated files to a visible directory (not hidden `.dart_tool/`), making them inspectable and easier to debug. Constitution §VII requires all user-facing strings in ARB files from project inception. Works identically on all three platforms (Android, iOS, Web).

**Alternatives considered:** `synthetic-package: true` (default) — generated code in `.dart_tool/flutter_gen/` is gitignored and invisible in some IDEs.

---

## Web Platform Specifics

**Decision:** The `web/` directory is scaffolded by `flutter create --platforms android,ios,web`. Use `--web-renderer canvaskit` for all web builds. Do not customise `web/manifest.json` or service workers in this feature (deferred per spec Out of Scope).

**Key `web/` files:**
- `web/index.html`: main entry; uses `flutter.js` bootstrapper. Base href is `/` by default.
- `web/manifest.json`: PWA manifest with app name from `pubspec.yaml`; not customised in this feature.
- `web/favicon.png` + `icons/`: generated placeholder assets.

**`flutter config --enable-web`** must be run once per Flutter installation, including CI. Does not modify project files.

**Rationale:** CanvasKit gives pixel-identical rendering to native (same Skia paint engine) and is the path forward as the HTML renderer is deprecated. The Wasm/Skwasm renderer is opt-in and not yet stable for general audiences (requires `SharedArrayBuffer` + COOP/COEP HTTP headers).

**Alternatives considered:** `--web-renderer html` — deprecated, known fidelity gaps. `--web-renderer auto` — inconsistent behaviour across UA, avoid for new projects. `--wasm` — future default but not yet ready.

---

## Golden Tests

**Decision:** Use `flutter_test`'s built-in `matchesGoldenFile()`. Store goldens in `test/goldens/`. Mark as binary in `.gitattributes`. Use tolerance-based comparator for cross-platform rendering consistency.

**Rationale:** Constitution §II says golden tests SHOULD be used for design-system components. Built-in matcher requires no additional dependencies. Tolerance comparator prevents flaky failures from sub-pixel rendering differences across CI OS.

**Alternatives considered:** `alchemist` package (Very Good Ventures) — adds multi-device golden generation and `ci` vs `local` mode; worth adopting later as design system matures.

---

## `pubspec.yaml` Version Pinning

**Decision:** Use caret constraints (`^`) for all third-party packages, pinned to currently tested minimum. Commit `pubspec.lock`. Pin Flutter SDK version in CI via `subosito/flutter-action@v2`'s `flutter-version` parameter.

**Rationale:** Caret constraints allow semver-compatible updates while preventing major-version breaking changes. Committed `pubspec.lock` ensures identical resolved versions across all developers and CI runs. Pinning Flutter SDK in CI prevents surprise breakages from SDK updates.

**Alternatives considered:** Exact pinning (`flutter_secure_storage: 9.2.2`) — overly rigid, blocks transitive patch fixes. No `pubspec.lock` in VCS — appropriate for published libraries, wrong for applications.