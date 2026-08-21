import CoreLocation
import Foundation
import SwiftUI

struct Place: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let distance: String
    /// Short street/area line shown under the name in search results.
    var address: String = ""
    let ratingLabel: String
    let summary: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let accentColor: Color
    let gallerySymbols: [String]
    let facilitySymbols: [String]
    let elevatorDetails: [ElevatorDetail]
    let reviewsSummary: String
    /// Overall accessibility grade used to color and filter the map pin.
    /// nil for live search results until the backend enrichment resolves.
    var grade: OverallAccessibility? = nil
    /// Populated for places from a real MKLocalSearch result once the
    /// backend enrichment call resolves — nil (and unused) for the mock
    /// mock detail fixtures. See PlaceDetailView's live grade loading.
    var isLiveResult: Bool = false

    struct ElevatorDetail: Hashable {
        let symbol: String
        let label: String
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}

extension Place {
    /// Canonical place key shared with Supabase edge functions.
    ///
    /// Delegates to PlaceCacheStore.key rather than re-deriving the format:
    /// two copies of this string is how the device cache and the review /
    /// saved-place keys drift apart, and they must address the same row.
    static func canonicalPlaceId(lat: Double, lng: Double) -> String {
        PlaceCacheStore.key(lat: lat, lng: lng)
    }

    static func canonicalPlaceId(from coordinate: CLLocationCoordinate2D) -> String {
        canonicalPlaceId(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    /// Builds a minimal Place from a real on-device MKLocalSearch result.
    /// The decorative mock fields (gallery, elevator details, canned
    /// reviews summary) don't exist for a real place, so they're left
    /// empty rather than faked — PlaceDetailView only renders them when
    /// non-empty, and shows the real, live Accessibility Grade instead.
    static func fromSearchResult(name: String, category: String, coordinate: CLLocationCoordinate2D, address: String = "", distance: String = "") -> Place {
        Place(
            id: UUID(),
            name: name,
            category: category,
            distance: distance,
            address: address,
            ratingLabel: "",
            summary: "",
            description: "",
            coordinate: coordinate,
            accentColor: .accentColor,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            isLiveResult: true
        )
    }
}

