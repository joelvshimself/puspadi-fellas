# Rollspot Android

Jetpack Compose app. Business logic (API, auth, grading, forms) lives in the shared Kotlin Multiplatform
module `Mobile/shared`; this app only holds Android views and platform glue. See `/CLAUDE.md`.

## Build

The Gradle root is `Mobile/`, not this folder. Open `Mobile/` in Android Studio.

```bash
cd Mobile
# `./gradlew` picks Android Studio's bundled JDK on macOS if JAVA_HOME is unset.
./gradlew :androidApp:assembleDebug
./gradlew :androidApp:installDebug        # on a running emulator/device
```

**Emulator + install:** read **[EMULATOR.md](EMULATOR.md) first** (create `Pixel_9` AVD once, Wi‑Fi/DNS checklist).

```bash
export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"
Mobile/scripts/run-android-debug.sh              # start Pixel_9 + install
Mobile/scripts/run-android-debug.sh --create-avd # first time on a new machine
```

Do not run `./gradlew installDebug` until `start-pixel-9-emulator.sh` reports boot and network OK.

## Configuration (`Mobile/local.properties`, gitignored)

```properties
sdk.dir=/Users/<you>/Library/Android/sdk
# Local backend (`cd backend && npm run dev`), as seen from the emulator:
rollspot.apiBaseUrl=http://10.0.2.2:8787
# Google Sign-In (F1): the *web* OAuth client ID from Google Cloud
rollspot.googleWebClientId=
```

Without `rollspot.apiBaseUrl` the app talks to production (`https://rollspot-api.joecast208.workers.dev`).
