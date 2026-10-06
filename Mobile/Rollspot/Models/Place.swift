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
    /// Stable Apple place identity. This is the only Apple Maps value that is
    /// persisted by the backend; all display data stays in MapKit.
    var applePlaceId: String? = nil
    /// Overall accessibility grade used to color and filter the map pin.
    /// nil for live search results until the backend enrichment resolves.
    var grade: OverallAccessibility? = nil
    /// Populated for places from a real MKLocalSearch result once the
    /// backend enrichment call resolves — nil (and unused) for the mock
    /// mock detail fixtures. See PlaceDetailView's live grade loading.
    var isLiveResult: Bool = false
    /// Detail fields supplied by the current in-memory MapKit result.
    var phone: String? = nil
    var website: String? = nil
    var openingHours: String? = nil

    struct ElevatorDetail: Hashable {
        let symbol: String
        let label: String
    }

    /// Fixture-only identity for previews. Live MapKit results carry an Apple
    /// Place ID on iOS 18 and later.
    var reviewPlaceId: String { applePlaceId ?? "preview:\(id.uuidString)" }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}

extension Place {
    /// Builds a minimal Place from a real on-device MKLocalSearch result.
    /// The decorative mock fields (gallery, elevator details, canned
    /// reviews summary) don't exist for a real place, so they're left
    /// empty rather than faked — PlaceDetailView only renders them when
    /// non-empty, and shows the real, live Accessibility Grade instead.
    static func fromSearchResult(
        name: String,
        category: String,
        coordinate: CLLocationCoordinate2D,
        address: String = "",
        distance: String = "",
        applePlaceId: String? = nil,
        phone: String? = nil,
        website: String? = nil
    ) -> Place {
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
            applePlaceId: applePlaceId,
            isLiveResult: true,
            phone: phone,
            website: website
        )
    }
}
