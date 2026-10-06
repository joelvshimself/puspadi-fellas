# Rollspot Android

Jetpack Compose app. Business logic (API, auth, grading, forms) lives in the shared Kotlin Multiplatform
module `Mobile/shared`; this app only holds Android views and platform glue. See `/CLAUDE.md`.

## Build

The Gradle root is `Mobile/`, not this folder. Open `Mobile/` in Android Studio.

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home   # JDK 25
cd Mobile
./gradlew :androidApp:assembleDebug
./gradlew :androidApp:installDebug        # on a running emulator/device
```

## Configuration (`Mobile/local.properties`, gitignored)

```properties
sdk.dir=/Users/<you>/Library/Android/sdk
# Local backend (`cd backend && npm run dev`), as seen from the emulator:
rollspot.apiBaseUrl=http://10.0.2.2:8787
# Google Sign-In (F1): the *web* OAuth client ID from Google Cloud
rollspot.googleWebClientId=
```

Without `rollspot.apiBaseUrl` the app talks to production (`https://api.rollspot.app`).
