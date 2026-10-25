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
# Push notifications: Firebase console → Project settings → Your apps → Android app
# (the same values google-services.json carries; the file itself isn't used)
rollspot.firebase.apiKey=
rollspot.firebase.appId=
rollspot.firebase.projectId=
rollspot.firebase.senderId=
```

Without the four `rollspot.firebase.*` values the app builds and runs normally, with push off
(the Notifications switches still save, and review reminders still work: they're local).

Without `rollspot.apiBaseUrl` the app talks to production (`https://rollspot-api.joecast208.workers.dev`).

## Release build for Google Play

Create the upload key once and keep it (and its passwords) somewhere safe outside the repo. Losing it
means asking Google to reset the upload key, which takes days.

```bash
keytool -genkeypair -v -keystore ~/rollspot-upload.jks -alias upload \
  -keyalg RSA -keysize 2048 -validity 10000
```

Then add to `Mobile/local.properties` (paths are relative to `Mobile/`, or absolute):

```properties
rollspot.release.storeFile=/Users/<you>/rollspot-upload.jks
rollspot.release.storePassword=...
rollspot.release.keyAlias=upload
rollspot.release.keyPassword=...
```

Raise `versionCode` in `app/build.gradle.kts` for every upload, then build the bundle:

```bash
cd Mobile && ./gradlew :androidApp:bundleRelease
# → android/app/build/outputs/bundle/release/androidApp-release.aab
```

Without the `rollspot.release.*` values `bundleRelease` still builds, unsigned, and Play rejects it.

Play Console asks for two links; both are on the website:
- Privacy policy: `/privacy`
- Account deletion: `/delete-account`
