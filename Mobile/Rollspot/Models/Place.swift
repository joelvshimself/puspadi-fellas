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
    /// Rollspot place ID from the shared place directory (same on iOS and Android).
    var placeId: String? = nil
    /// OpenStreetMap element behind this place, e.g. "way/520645071".
    var osmRef: String? = nil
    /// Overall accessibility grade used to color and filter the map pin.
    /// nil for live search results until the backend enrichment resolves.
    var grade: OverallAccessibility? = nil
    /// True for places from the Rollspot directory; false for mock detail fixtures.
    var isLiveResult: Bool = false
    /// Detail fields from OpenStreetMap, via the place directory.
    var phone: String? = nil
    var website: String? = nil
    var openingHours: String? = nil

    struct ElevatorDetail: Hashable {
        let symbol: String
        let label: String
    }

    /// The ID every API call uses. Previews and fixtures have no directory ID.
    var reviewPlaceId: String { placeId ?? "preview:\(id.uuidString)" }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.id == rhs.id
    }
}

extension Place {
    /// Builds a minimal Place from a search result or deep link.
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
        placeId: String? = nil,
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
            placeId: placeId,
            isLiveResult: true,
            phone: phone,
            website: website
        )
    }
}
