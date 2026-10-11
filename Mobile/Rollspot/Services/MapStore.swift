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
    /// Search results for the current query.
    @Published private(set) var results: [Place] = []
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
        // Half the larger side of the visible span, in meters (1° latitude ≈ 111 km).
        let spanMeters = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111_000
        model.onRegionChanged(lat: region.center.latitude, lng: region.center.longitude, radiusMeters: Int32(spanMeters / 2))
    }

    func queryChanged(_ text: String) {
        model.onQueryChanged(query: text)
    }

    /// Chooses a grade to filter to; choosing the active one clears it. The shared model widens the area if needed.
    func setGradeFilter(_ grade: OverallAccessibility) {
        model.setGradeFilter(grade: grade.shared)
    }

    /// A place was opened from the map or the list: remember it for the recents.
    func opened(_ place: Place) {
        guard let id = place.placeId else { return }
        model.select(placeId: id)
    }

    func refresh() {
        model.refresh()
    }

    private func apply(_ state: MapState) {
        let origin = CLLocationCoordinate2D(latitude: state.centerLat, longitude: state.centerLng)
        places = state.pins.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
        results = state.freshResults.map { NearbyPlacesService.makePlace(from: $0.place, distanceFrom: origin) }
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
        if !state.isLoading, !state.pins.isEmpty || state.error != nil {
            hasLoadedOnce = true
        }
    }
}
