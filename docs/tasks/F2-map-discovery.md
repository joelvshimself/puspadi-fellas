# F2: Map & place discovery

## Goal
The home map shows nearby places with their accessibility grade on both apps. Rendering and search are
native (Apple Maps on iOS, OpenStreetMap on Android). What happens to the results is shared: resolving
them to Rollspot places, fetching grades with a concurrency limit, deduping and ordering.

## Today
- iOS: `Services/NearbyPlacesService.swift` (MapKit `MKLocalSearch`, "shopping mall", 25 results),
  `Services/LocationManager.swift`, `Views/Home/HomeMapView.swift`, `SearchSheet.swift`, `OnboardingIntroSheet.swift`.
- Android: `ui/screens/home/HomeScreen.kt` + `HomeViewModel.kt`, `components/SearchBottomSheet.kt`,
  `data/services/LocationService.kt`, all on **Google Maps**, which has to be replaced.

## Shared
- [ ] `PlaceSearchProvider` interface `search(region, query): List<PlaceRef>`. Each platform implements it.
- [ ] `map/MapModel`: given the visible region, debounce, call the provider, `resolve-batch` (F0), merge
      grades into pins, keep the selection, and handle the search query and recent searches.
      Exposes `StateFlow<MapState>`.
- [ ] Dedupe (normalized name + distance), distance labels, sorting. Unit tests for each.

## iOS
- [ ] `MapKitPlaceSearchProvider` wraps the existing `NearbyPlacesService`.
- [ ] `HomeMapView` and `SearchSheet` render `MapModel` state. Pin color comes from the overall grade.

## Android
- [ ] Map: **MapLibre Native** (recommended) or osmdroid, with an OSM-based tile source that allows app
      use (e.g. OpenFreeMap or MapTiler free tier). The public tile.openstreetmap.org servers aren't
      allowed for apps at scale. Attribution "© OpenStreetMap contributors" has to be visible.
- [ ] `OsmPlaceSearchProvider`: Overpass API for malls in the region (`shop=mall`), and Photon or
      Nominatim for text search (respect their rate limits; debounce in shared).
- [ ] Location permission and "center on me", using `LocationService.kt` without Play Services if possible.

## Acceptance criteria
- Standing in the same spot (e.g. Kuta), both apps show the same malls with the same grade colors.
- Tapping a pin on either app opens place detail (F3) with the same Rollspot `placeId`.
- Panning doesn't flood the API: requests are debounced and capped (check the Worker logs).
