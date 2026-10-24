# Android application

## Architecture

`RollspotApplication.onCreate` constructs the app-wide `RollspotSdk` with `AndroidTokenStore` and restores
the session. `MainActivity` handles intents and hosts the Compose `RollspotApp` `NavHost`.

Routes cover home, place detail, saved, auth, profile/settings/account/about, contribute search, and
contribute flow. Thin ViewModels hold shared KMP models; Compose normally observes them with
`collectAsStateWithLifecycle`.

## Feature map

| Feature | UI/ViewModel | Native dependency | Server interaction |
|---|---|---|---|
| Map/search/filter | `HomeScreen`, `HomeViewModel`, `PinMap` | MapLibre/OpenFreeMap, LocationManager | nearby/search |
| Place detail | `PlaceDetailScreen`, `PlaceDetailViewModel` | `geo:` directions, dial intent | detail/reviews/photos/save |
| Contribution | `ContributeFlowScreen`, `ContributeFlowViewModel` | System Photo Picker, JPEG encoder | media PUTs and review POST |
| Auth | `AuthFlowScreen`, `AuthViewModel` | Credential Manager/Google ID | Better Auth |
| Profile/account | `ProfileScreen`, `SettingsScreens` | Photo Picker | profile/avatar/reviews/account |
| Saved places | profile/saved route | none | saved-place endpoints |

## Native capabilities and storage

- MapLibre 13.6.1 loads the OpenFreeMap Liberty style.
- Fine/coarse location uses platform `LocationManager`, with an eight-second request timeout.
- System Photo Picker requires no storage permission; images resize to 2048 px at JPEG quality 80.
- Google identity uses Credential Manager.
- `AndroidTokenStore` encrypts the token with AES-GCM and a non-exportable Android Keystore key, storing
  ciphertext in private SharedPreferences.

No Room, DataStore, WorkManager, service, receiver, alarm, notification, camera capture, or background
location is implemented. Contribution drafts and recent searches are in memory.

## Configuration and build

- Application ID `com.rollspot.app`; min SDK 26; compile/target SDK 36; JVM 17.
- Gradle 9.1, AGP 8.13.2, Kotlin 2.4.20, Compose BOM 2026.05.01.
- `rollspot.apiBaseUrl` and `rollspot.googleWebClientId` come from `Mobile/local.properties`.
- Release cleartext traffic is blocked; debug permits localhost/`10.0.2.2`.
- Release minification is disabled.

`./gradlew :androidApp:assembleDebug :androidApp:testDebugUnitTest` passed during the audit, but there are
no Android app test sources. Gradle reports deprecations relevant to Gradle 10.

## Deep links

The manifest accepts `puspadi://auth` and `puspadifellas://place?place_id=...`. There is no verified HTTPS
Android App Link or `assetlinks.json`. Place IDs containing `/` are interpolated directly into Navigation
routes, which may break route matching. The tracked web place page omits the `place_id` expected by
`MainActivity`, so its open-app button cannot resolve a place (**potential issue**).

## Error behavior and gaps

- Map/detail provide retry; saved/profile initial loads sometimes suppress errors and display empty state.
- Map style-load failure has no user-facing recovery.
- Location permission is requested immediately and cached location has no age/accuracy gate.
- Contribution draft state is lost on process death despite UI language implying it is saved.
- UI says “Take or upload,” but only gallery picking exists.
- Contribution login uses an unmasked password field.
- Many strings are hard-coded English despite resource translations.
- `ReviewViewModel` is unused; active contribution calls the shared model directly.

## Cross-platform parity

| Capability | iOS | Android | Difference / gap |
|---|---|---|---|
| API place map/search/filter | Yes | Yes | MapKit vs MapLibre/OpenFreeMap |
| Place detail/reviews/photos/save | Yes | Yes | Native presentation differs |
| Six-category contribution | Yes | Yes | iOS persists a draft; Android draft is volatile |
| Camera capture | Yes | No | Android gallery only |
| Email auth | Yes | Yes | Shared AuthModel |
| Apple sign-in | Yes | No | Platform-specific |
| Google sign-in | Code present; config placeholder | Yes with config | Public client IDs required |
| Profile/avatar/review deletion | Yes | Yes | iOS profile photo add flow is incomplete |
| Shared HTTPS place links | Universal Links | No | Android custom scheme only |
| Offline database | No | No | Server state reload |
| Push/realtime | No | No | Explicit reload |
| Localization | In-code English/Indonesian | Partial resources; hard-coded English remains | Not full parity |
