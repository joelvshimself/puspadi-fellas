import CoreLocation
import Foundation
import MapKit
import Shared

/// SwiftUI face of the shared `MapModel`: forwards the camera and the search text
/// to it and republishes its state. What the pins are, search, debouncing and
/// ordering all happen in the shared module; Apple Maps only draws.
@MainActor
final class MapStore: ObservableObject {
    private let model = MapModel(provider: RollspotServices.sdk.placeSearch)
    private var observer: Task<Void, Never>?

    /// Places for the visible region, nearest first, graded.
    @Published private(set) var places: [Place] = []
    /// What the map draws: the shared rule (no pins until a grade filter is chosen).
    @Published private(set) var visiblePlaces: [Place] = []
    /// True once the query is long enough to search (shared minimum length).
    @Published private(set) var isSearchActive = false
    /// Search results for the current query.
    @Published private(set) var results: [Place] = []
    /// Addresses and areas from Apple Maps search, listed after the places; tapping one moves the map.
    @Published private(set) var areaResults: [AreaResult] = []
    /// Set while the map is somewhere Rollspot has no places yet: the covered region to offer instead.
    @Published private(set) var uncoveredFallback: CoverageRegion?
    /// Recently opened places matching the query: the clock rows while typing.
    @Published private(set) var recents: [Place] = []
    @Published private(set) var isSearching = false
    @Published private(set) var errorMessage: String?
    /// The design shows no pins until a grade filter is chosen; the map draws `places` of this grade only.
    @Published private(set) var gradeFilter: OverallAccessibility?
    /// Set when the filter widened the search area; the map should move here.
    @Published private(set) var focusRegion: MKCoordinateRegion?
    @Published private(set) var focusNonce = 0
    /// True once the first nearby request has finished, successfully or not.
    @Published private(set) var hasLoadedOnce = false

    init() {
        model.areaSearch = AppleAreaSearchProvider()
        apply(model.state.value)
        observer = Task { [weak self] in
            guard let states = self?.model.state else { return }
            for await state in states {
                self?.apply(state)
            }
        }
    }

    deinit {
        observer?.cancel()
        model.dispose()
    }

    /// The camera settled. The model debounces and skips small moves.
    func regionChanged(_ region: MKCoordinateRegion) {
        // Same radius formula as Android, from the shared module.
        model.onViewportChanged(
            lat: region.center.latitude,
            lng: region.center.longitude,
            latitudeDelta: region.span.latitudeDelta,
            longitudeDelta: region.span.longitudeDelta
        )
    }

    func queryChanged(_ text: String) {
        model.onQueryChanged(query: text)
    }

    /// Flies the map to an address or area from the search results; the shared model loads places there.
    func goTo(_ area: AreaResult) {
        model.goTo(area: area)
    }

    /// "Go to Bali" from the not-covered notice.
    func goTo(_ region: CoverageRegion) {
        model.goTo(region: region)
    }

    /// Chooses a grade to filter to; choosing the active one clears it. The shared model widens the area if needed.
    func setGradeFilter(_ grade: OverallAccessibility) {
        model.setGradeFilter(grade: grade.shared)
    }

    /// A place was opened from the map or the list: remember it for the recents.
    func opened(_ place: Place) {
        guard let id = place.placeId else { return }
        let state = model.state.value
        if let known = (state.pins + state.results + state.recentPins).first(where: { $0.id == id }) {
            model.open(place: known.place)
        } else {
            // Opened from outside the map (deep link, saved list): fetch it so it lands in the recents too.
            Task { if let fetched = try? await RollspotServices.sdk.places.place(key: id) { model.open(place: fetched) } }
        }
    }

    func refresh() {
        model.refresh()
    }

    private func apply(_ state: MapState) {
        let origin = CLLocationCoordinate2D(latitude: state.centerLat, longitude: state.centerLng)
        places = state.pins.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
        visiblePlaces = state.visiblePins.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
        isSearchActive = state.isSearchActive
        results = state.freshResults.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
        areaResults = state.areaResults
        uncoveredFallback = state.isOutsideCoverage ? state.nearestCoveredRegion : nil
        recents = state.matchingRecents.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
        gradeFilter = state.gradeFilter.map { OverallAccessibility($0) }
        if let focus = state.focus, Int(focus.nonce) != focusNonce {
            focusNonce = Int(focus.nonce)
            let meters = Double(focus.radiusMeters)
            let latDelta = meters * 2 / 111_000
            focusRegion = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: focus.lat, longitude: focus.lng),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: latDelta)
            )
        }
        isSearching = state.isSearching
        errorMessage = state.error
        hasLoadedOnce = state.hasLoaded
    }
}
