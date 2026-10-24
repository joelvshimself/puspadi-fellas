# Getting started

## Prerequisites

| Tool | Verified requirement |
|---|---|
| Node/npm | Required; no version is pinned |
| JDK | JDK 25 path is used by repository instructions; Gradle compiles Android to JVM 17 |
| Gradle | Wrapper 9.1.0 in `Mobile/gradle/wrapper` |
| Xcode | iOS 18 SDK capable; exact Xcode version is not pinned |
| Android SDK | compile/target SDK 36, min SDK 26 |
| Wrangler | locked to 4.131.0 by `backend/package-lock.json` |

## Backend

```bash
cd backend
npm install
cp .dev.vars.example .dev.vars
npm run db:migrate:local
npm run dev
```

Local API: `http://localhost:8787`. Auth emails are logged by the local Worker when `RESEND_API_KEY`
is absent. Do not commit `.dev.vars`.

Useful checks:

```bash
npm run check                    # TypeScript compilation
npm test                         # currently the same compilation check
npm run db:migrate:remote        # production migration; requires Cloudflare auth
npm run deploy                   # Worker deployment; requires Cloudflare auth
```

## Shared module and Android

```bash
export JAVA_HOME=/opt/homebrew/opt/openjdk@25/libexec/openjdk.jdk/Contents/Home
cd Mobile
./gradlew :shared:testDebugUnitTest :shared:iosSimulatorArm64Test
./gradlew :androidApp:assembleDebug
```

For the Android emulator, place these uncommitted values in `Mobile/local.properties`:

```properties
rollspot.apiBaseUrl=http://10.0.2.2:8787
rollspot.googleWebClientId=YOUR_PUBLIC_WEB_CLIENT_ID
```

Use `Mobile/scripts/run-android-debug.sh` to start the configured emulator workflow before installing a
debug build. The `Mobile/android/EMULATOR.md` path mentioned in older repository guidance is not present
at this baseline.

## iOS

Open `Mobile/Rollspot.xcodeproj`. The first Xcode build phase invokes
[`Mobile/scripts/build-shared-for-xcode.sh`](../Mobile/scripts/build-shared-for-xcode.sh), which builds and
embeds the static `Shared` KMP framework.

```bash
xcodebuild -project Mobile/Rollspot.xcodeproj -scheme Rollspot \
  -destination 'generic/platform=iOS Simulator' ARCHS=arm64 build
```

For a local backend, set the Run scheme environment variable:

```text
ROLLSPOT_API_BASE_URL=http://localhost:8787
```

Google Sign-In also requires replacing the public placeholders in `Mobile/Info.plist`. Sign in with Apple
must be enabled for `com.puspadifellas.app`.

## Live integration test

Against a disposable/local backend:

```bash
cd Mobile
ROLLSPOT_LIVE_URL=http://localhost:8787 \
  ./gradlew :shared:testDebugUnitTest --tests '*LiveBackendTest*' --rerun
```

The suite creates and deletes account/review data. Do not target production without explicit approval.

## Environments

| Environment | API selection |
|---|---|
| Worker local | Wrangler on port 8787 |
| iOS debug | `ROLLSPOT_API_BASE_URL`, otherwise production default |
| Android local | `rollspot.apiBaseUrl` in `Mobile/local.properties` |
| Production default | `https://rollspot-api.joecast208.workers.dev` |

There is no tracked staging environment or CI workflow. Production account access, secret presence, and
deployed migration state are **Unknown** from the repository.
