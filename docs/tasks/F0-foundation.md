# F0: Foundation: shared module, API client, place identity

**Blocks every other feature. Do this first, and keep it small.**

## Goal
Create the Kotlin Multiplatform module that both apps use for business logic. Wire it into both apps, and
make place IDs platform-neutral so that an Android user (using OSM) and an iOS user (using Apple Maps)
reviewing the same mall write to the same place.

## Today
- The backend keys everything by `apple_place_id` (`backend/migrations/0001_initial.sql`: `places`,
  `saved_places`, `reviews`, `accessibility_signals`, `place_photos`). Android can't produce Apple IDs.
  `wrangler.jsonc` still has a placeholder `database_id`, so nothing is deployed yet and it's fine to
  rewrite `0001`.
- iOS calls the API through `Mobile/Rollspot/Services/CloudflareAPIClient.swift`, with the token in `AuthTokenStore.swift`.
- `Mobile/android` is a standalone Gradle project that still uses **Supabase and Google Maps**
  (`app/build.gradle.kts`, `data/SupabaseClient.kt`). Both have to go.

## Backend
- [ ] Platform-neutral place identity: `places.id` (Rollspot ID) plus a table
      `place_external_ids(source TEXT /* apple|osm */, external_id TEXT, place_id TEXT, PRIMARY KEY(source, external_id))`.
      Re-key `saved_places`, `reviews`, `accessibility_signals` and `place_photos` to `place_id`.
- [ ] `POST /v1/places/resolve {source, externalId, name, lat, lng, address?, category?}` → `{placeId, ...}`.
      Look up an existing external ID first. If there isn't one, match an existing place by normalized name
      within ~100 m (normalization is the same as `NearbyPlacesService.normalized`). Otherwise create a new place.
      Attach the external ID in both the match and create cases.
- [ ] `POST /v1/places/resolve-batch` for map pins (up to 50), returning the grade with each place to avoid N+1.
- [ ] Update `/v1/places/:id/*` and `/v1/saved-places` to use Rollspot IDs.
- [ ] Write the API contract down in `backend/API.md` (one line per endpoint: method, path, auth, request, response).

## Shared (`Mobile/shared`)
- [ ] Make `Mobile/` the Gradle root: `settings.gradle.kts` includes `:shared` and `:androidApp`
      (projectDir `android/app`), and has a version catalog `gradle/libs.versions.toml`.
- [ ] KMP module with targets `androidTarget`, `iosArm64`, `iosSimulatorArm64`, and the SKIE plugin.
      Libraries: Ktor (OkHttp engine on Android, Darwin engine on iOS), kotlinx.serialization, coroutines,
      kotlinx-datetime, multiplatform-settings.
- [ ] `api/RollspotApi`: one suspend function per endpoint in `backend/API.md`, plus DTOs.
      Bearer token comes from a `TokenStore` interface, and errors map to `ApiError(status, code, message)`.
- [ ] `TokenStore` expect/actual: Keychain on iOS, EncryptedSharedPreferences/DataStore on Android.
- [ ] `RollspotSdk` entry point that builds the API, repositories and models once (simple manual DI).
- [ ] `places/PlaceRef(source, externalId, name, lat, lng, ...)` and `PlaceRepository.resolve()`.
- [ ] Port the pure logic from Swift, with unit tests: `collapseAccessibility` and `OverallAccessibility`
      (`Models/AccessibilityGrade.swift`, without colors/icons), the `NetworkRetry` policy, and `ConcurrencyLimit`.
- [ ] `./gradlew :shared:allTests` passes.

## iOS
- [ ] Xcode build phase: `./gradlew :shared:embedAndSignAppleFrameworkForXcode`, then `import Shared`.
- [ ] Replace `CloudflareAPIClient.swift` and `AuthTokenStore.swift` with the shared versions (the logic
      leaves Swift; only thin adapters stay).
- [ ] `Place.applePlaceId` stays as the *external* ID, and `reviewPlaceId` becomes the resolved Rollspot ID.

## Android
- [ ] Remove the Supabase and Google Maps dependencies and `SupabaseClient.kt`. Depend on `:shared`.
- [ ] `applicationId`, `API_BASE_URL` in BuildConfig, and the app builds with `./gradlew :androidApp:assembleDebug`.
- [ ] Keep the existing screens compiling, using stubbed data where needed. The features rebuild them.

## Acceptance criteria
- Both apps build from a clean checkout following the `CLAUDE.md` commands.
- Resolving the same mall from an Apple ID and from an OSM ID returns the same `placeId` (cover this with a backend test or script).
- No `supabase` or `maps.google`/`play-services-maps` left anywhere in the repo.

## Out of scope
Feature screens. Leave those to F1–F5.
