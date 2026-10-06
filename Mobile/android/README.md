# Rollspot Android

Android port of the Rollspot iOS app — a wheelchair map app that shows accessibility information for places.

## Tech Stack

- **Language**: Kotlin
- **UI**: Jetpack Compose + Material 3
- **Architecture**: MVVM with ViewModels and StateFlow
- **Backend**: Supabase (Auth, Postgrest, Functions, Storage, Realtime)
- **Maps**: Google Maps SDK for Android
- **Location**: Google Play Services Location API
- **Image Loading**: Coil 3
- **Serialization**: kotlinx.serialization

## Project Structure

```
app/src/main/java/com/rollspot/app/
├── RollspotApplication.kt           # App entry point
├── MainActivity.kt                  # Main activity
├── data/
│   ├── SupabaseClient.kt           # Supabase client setup
│   ├── models/                     # Data models (Place, AccessibilityGrade, etc.)
│   └── services/                   # Services (AccessibilityService, LocationService, etc.)
└── ui/
    ├── RollspotApp.kt              # Main navigation setup
    ├── theme/                      # Material 3 theme
    ├── components/                 # Reusable UI components
    └── screens/                    # App screens (Home, PlaceDetail, Saved, Contribute)
```

## Building and Running

### Prerequisites

1. **Android Studio**: Hedgehog (2023.1.1) or newer
   - Download from: https://developer.android.com/studio
   - Includes Android SDK, build tools, and emulator
2. **JDK**: 17 or newer (bundled with Android Studio)
3. **Android SDK**: API 26+ (minimum), API 35 (target) (installed via Android Studio SDK Manager)

**Note**: This project cannot be built on the cloud VM as it requires the Android SDK. Build it locally in Android Studio or on a CI system with Android SDK installed.

**Gradle JVM Compatibility**: This project uses Gradle 8.11.1 which supports JDK 8-25. If you encounter JVM version errors, set the Gradle JDK in Android Studio: **Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** and select JDK 17 or 21.

### Setup

1. Open the project in Android Studio:
   ```bash
   cd Mobile/android
   # Open in Android Studio or use:
   # studio .
   ```

2. **Configure Supabase credentials** (optional — defaults are provided):
   
   Create or edit `local.properties` in the `Mobile/android/` directory:
   ```properties
   SUPABASE_URL=https://svztcykgmlgjiqfqpimc.supabase.co
   SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
   ```
   
   The default values are already configured in `app/build.gradle.kts` BuildConfig, so this step is optional unless you want to use different credentials.

3. **Configure Google Maps API Key** (required for map display):
   
   Add to `local.properties`:
   ```properties
   MAPS_API_KEY=your_google_maps_api_key_here
   ```
   
   Or set as an environment variable:
   ```bash
   export MAPS_API_KEY=your_google_maps_api_key_here
   ```
   
   **To get a Google Maps API Key:**
   - Go to [Google Cloud Console](https://console.cloud.google.com/)
   - Create a new project or select an existing one
   - Enable "Maps SDK for Android" API
   - Create credentials → API Key
   - Restrict the key to Android apps with your package name: `com.rollspot.app`

4. Sync Gradle:
   ```bash
   ./gradlew sync
   ```

5. Let Android Studio download/configure the Android SDK (first-time setup)

6. Build:
   ```bash
   ./gradlew assembleDebug
   ```
   
   Or use Android Studio's Build menu → Make Project.

7. Run on device/emulator:
   ```bash
   ./gradlew installDebug
   ```
   
   Or use Android Studio's Run button (▶️).

## Features Ported from iOS

### ✅ Implemented

- **Home Screen**: Map view with nearby places
  - Google Maps integration
  - Location services
  - Nearby places from Supabase directory
  - Glass morphism UI buttons
  - Filter and profile buttons

- **Search Bottom Sheet**: Liquid Glass-style bottom sheet
  - Search bar
  - Category tabs (Explore / Saved / Contribute)
  - Places list

- **Place Detail Screen**: Full accessibility information
  - Accessibility grade badge
  - Place info (address, phone, etc.)
  - Tabs for Facilities / Routes / Reviews
  - Per-feature accessibility grades

- **Saved Screen**: Placeholder for saved places

- **Contribute Screen**: Placeholder for contributing reviews

- **Data Layer**:
  - Supabase client integration
  - Models: Place, AccessibilityGrade, MobilityProfile
  - Services: AccessibilityService, LocationService, NearbyPlacesService
  - Edge Function integration (place-accessibility, places-nearby)

### 🚧 TODO / Stubbed

- Auth flow (login/signup)
- Saved places functionality
- Review submission form
- Route recording
- Photo upload
- Profile screen
- Deep link handling for place sharing
- Splash screen
- Onboarding flow

## Backend Integration

The app connects to the same Supabase backend as the iOS app:

- **URL**: `https://svztcykgmlgjiqfqpimc.supabase.co`
- **Tables**: `place_cache`, `accessibility_signals`, `reviews`, `saved_places`, etc.
- **Edge Functions**:
  - `place-accessibility`: Enriches a place with Google/OSM accessibility data
  - `places-nearby`: Returns curated directory places near a coordinate
  - `submit-accessibility-review`: Accepts review submissions

See `backend/supabase/` in the root monorepo for the full backend schema and functions.

## Architecture Notes

### MVVM Pattern

Each screen follows the MVVM pattern:
- **View**: Composable functions in `ui/screens/`
- **ViewModel**: State management and business logic
- **Model**: Data classes in `data/models/`

Example:
```
HomeScreen.kt        → UI (Composable)
HomeViewModel.kt     → State + business logic
Place.kt             → Data model
```

### State Management

- `StateFlow` for UI state
- `MutableStateFlow` for internal state updates
- `collectAsState()` in Composables to observe state

### Supabase Client

The Supabase client is initialized once in `RollspotApplication.onCreate()` and accessed via the singleton `SupabaseClient.client`.

### Accessibility Service

Mirrors the iOS implementation:
- Device-side caching of place accessibility responses
- Request coalescing to prevent duplicate API calls
- Negative caching (backoff) for failed requests

## Testing

Run tests:
```bash
./gradlew test           # Unit tests
./gradlew connectedAndroidTest  # Instrumentation tests
```

## Troubleshooting

### Build fails with "Unresolved reference: BuildConfig"

Run Gradle sync:
```bash
./gradlew sync
```

### Gradle JVM version incompatibility

If you see "The project's Gradle version is incompatible with the Gradle JVM version", go to **Android Studio → Settings → Build, Execution, Deployment → Build Tools → Gradle → Gradle JDK** and select JDK 17 or 21 (not 25+).

### Maps not showing / blank map

- Check that you've set `MAPS_API_KEY` in `local.properties`
- Verify the API key has "Maps SDK for Android" enabled
- Check the key is restricted to package `com.rollspot.app`

### Location permission denied

Grant location permission in device Settings → Apps → Rollspot → Permissions → Location → Allow.

### Supabase functions fail

- Check network connectivity
- Verify `SUPABASE_URL` and `SUPABASE_ANON_KEY` are correct
- Check backend logs: `cd backend && npx supabase functions logs`

## Differences from iOS

1. **Maps**: Google Maps instead of Apple MapKit
2. **Location**: Google Play Services instead of CoreLocation
3. **UI Framework**: Jetpack Compose instead of SwiftUI
4. **Navigation**: Compose Navigation instead of NavigationStack
5. **Storage**: DataStore instead of UserDefaults (planned)
6. **Async**: Kotlin Coroutines + Flow instead of async/await + Combine

## Contributing

When adding new features, follow the existing patterns:
- Create a `Screen.kt` + `ViewModel.kt` pair for new screens
- Add models to `data/models/`
- Add services to `data/services/`
- Use Material 3 components
- Follow Material Design guidelines

## License

See the root `README.md` for license information.
