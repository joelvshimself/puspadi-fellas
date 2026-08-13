import CoreLocation
import Foundation
import SwiftUI

struct Place: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: String
    let distance: String
    let ratingLabel: String
    let summary: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let accentColor: Color
    let gallerySymbols: [String]
    let facilitySymbols: [String]
    let elevatorDetails: [ElevatorDetail]
    let reviewsSummary: String
    /// Populated for places from a real MKLocalSearch result once the
    /// backend enrichment call resolves — nil (and unused) for the mock
    /// `samples` below. See PlaceDetailView's live grade loading.
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
    /// Builds a minimal Place from a real on-device MKLocalSearch result.
    /// The decorative mock fields (gallery, elevator details, canned
    /// reviews summary) don't exist for a real place, so they're left
    /// empty rather than faked — PlaceDetailView only renders them when
    /// non-empty, and shows the real, live Accessibility Grade instead.
    static func fromSearchResult(name: String, category: String, coordinate: CLLocationCoordinate2D) -> Place {
        Place(
            id: UUID(),
            name: name,
            category: category,
            distance: "",
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

