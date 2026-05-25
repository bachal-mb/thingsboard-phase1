# Build Instructions

## Prerequisites

- **Flutter 3.32.x** (tested with 3.32.8)
  - Download: https://docs.flutter.dev/get-started/install
  - The repo's `.fvmrc` says 3.29.0 but the dependencies require >= 3.32
- **Android SDK** with:
  - Platform 35 (`android-35`)
  - Build-Tools 35 (`build-tools;35.0.0`)
  - NDK 29.0.13113456 (`ndk;29.0.13113456`)
  - Command-line tools (`cmdline-tools;latest`)
- **JDK 17** (e.g., Eclipse Temurin 17)

## Build

```bash
# 1. Clone
git clone https://github.com/bachal-mb/thingsboard-phase1.git
cd thingsboard-phase1

# 2. Install dependencies
flutter pub get

# 3. Build release APK
flutter build apk --release --no-tree-shake-icons --dart-define-from-file=configs.json

# Output: build/app/outputs/flutter-apk/app-release.apk
```

## What configs.json does

`configs.json` provides compile-time constants via `--dart-define-from-file`:

| Key | Purpose |
|-----|---------|
| `thingsboardApiEndpoint` | Server URL (https://thingsboard.cloud) |
| `thingsboardAndroidAppSecret` | Mobile App secret registered on the server |
| `thingsboardOAuth2CallbackUrlScheme` | OAuth2 callback scheme |
| `androidApplicationId` | Android package name |
| `androidApplicationName` | App display name |
| `appLinksUrlHost` | App Links host |
| `navigationType` | Bottom navigation type |

To point at a different ThingsBoard server, edit `configs.json` and rebuild.

## Notes

- `packages/thingsboard_client/` is a patched local copy of `thingsboard_client 4.2.1` that adds support for ThingsBoard Cloud (PAAS) and PE server types. The upstream package only supports CE (Community Edition).
- The release build is signed with the debug keystore. For Play Store distribution, configure a release keystore in `android/key.properties`.
