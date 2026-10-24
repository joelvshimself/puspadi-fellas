# iOS application

## Architecture

`RollspotApp` is the SwiftUI `@main` entry. It creates `LanguageManager` and `AuthSessionStore`, presents
`SplashScreenView`, then `ContentView`/`HomeMapView`. `HomeMapView` owns the main `NavigationStack`;
`HomeRoute` covers place, saved, contribute, and profile destinations. Auth uses a separate stack.

The app uses thin `ObservableObject` adapters over the static KMP `Shared` framework. Manual DI occurs in
`Services/RollspotServices.swift`. SKIE exposes shared `StateFlow` as `AsyncSequence`; UI adapters are
generally `@MainActor`.

## Feature map

| Feature | UI/entry | State/service | Server interaction / persistence |
|---|---|---|---|
| Home, map, search, filters | `Views/Home/HomeMapView.swift`, `SearchSheet.swift` | `MapStore`, shared `MapModel` | `/v1/places/nearby`, `/search`; MapKit renders |
| Place details | `Views/Detail/Mock/MockPlaceDetailView.swift` | `PlaceReviewStore`, `PlaceDetailModel` | place, photos, reviews endpoints |
| Contribution | `Views/Review/Mock/ContributeReviewFlowView.swift` | `ContributeFlowBridge`, `ReviewService` | photo PUTs then `POST /v1/reviews`; draft JSON in UserDefaults |
| Auth | `Views/Auth/` | `AuthSessionStore`, `AuthModel` | Better Auth; bearer in Keychain |
| Profile/account | `Views/Profile/` | `ProfileService`, shared profile models | profile, avatar, password, account/review deletion |
| Saved | `Views/Saved/SavedView.swift` | `SavedPlacesService` | `/v1/saved-places/*` |
| Photos | `Views/Photos/` | picker/camera and `ReviewService` | JPEG upload through shared review pipeline |
| Localization | all views | `LanguageManager` | in-code English/Indonesian dictionary, `@AppStorage` |

## Native capabilities

- MapKit annotations, camera, snapshots, Look Around, and Apple Maps directions.
- Core Location, when-in-use permission, one-shot location.
- Camera through `UIImagePickerController`; library through `PhotosPicker`.
- Keychain token (`AfterFirstUnlockThisDeviceOnly`).
- Associated domain `applinks:puspadi-fellas.pages.dev`.
- Sign in with Apple and Google Sign-In.
- Speech recognition/microphone implementation exists but no caller was found.

## Networking and state

Most requests originate in shared `RollspotApi`; Ktor Darwin performs HTTP. GET network/timeout failures
retry twice; writes require explicit retry. `ImageStore` uses `URLSession` and stores thumbnails under
Caches plus decoded images in `NSCache`. Bearer tokens are the only sensitive session state; draft review
content and place metadata are unencrypted in UserDefaults.

`KeychainTokenStore.save` suppresses persistence errors with `try?`, so a successful server sign-in may not
survive launch if Keychain writing fails (**potential issue**).

## Deep links

`DeepLinkRouter` supports `puspadifellas://place`, the Pages `/place` URL, and
`puspadi://auth/callback`. `RollspotApp.onOpenURL` first offers URLs to Google Sign-In, then place/auth
routing. Query-supplied place metadata can be shown before canonical resolution (**potential issue**).

## Build and configuration

- Deployment target: iOS 18.0; bundle `com.puspadifellas.app`; Swift setting 5.0.
- GoogleSignIn is resolved by Swift Package Manager (9.2.0 in `Package.resolved`).
- Xcode's first phase runs `Mobile/scripts/build-shared-for-xcode.sh`.
- Debug API override: `ROLLSPOT_API_BASE_URL`.
- `Mobile/Info.plist` still contains Google client-ID placeholders.

## Known implementation gaps

- No iOS unit/UI test target and no privacy manifest.
- Raw MapKit POI selection can produce `preview:<UUID>` rather than a Rollspot place ID, causing backend
  detail/review requests to fail.
- Profile “ADD PHOTOS” has no upload handler.
- `ContributeView` is a TODO stub and appears unreachable; current contribution uses the mock-named live UI.
- `ReviewWizardView`, `ReviewViewModel`, `CloudflareAPIClient`, and `AccessibilityService` are legacy or
  unreferenced; `ReviewService` still holds an unused legacy client.
- `PlaceAISummaryService` intentionally returns no summary until a backend endpoint exists.
- Account-deletion feedback is collected but not sent.
- Several failures are printed without visible retry UI; no realtime refresh exists.
