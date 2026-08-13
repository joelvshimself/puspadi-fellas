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

extension Place {
    static let samples: [Place] = [
        Place(
            id: UUID(),
            name: "Park 23",
            category: "Park",
            distance: "0.4 mi",
            address: "Market St, Downtown",
            ratingLabel: "Great",
            summary: "Wide paths, step-free entrances, and clear wayfinding for wheelchair users.",
            description: "A central green space with accessible restrooms, elevators at both main gates, and smooth paved loops around the lawn.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            accentColor: Color(red: 0.25, green: 0.55, blue: 0.35),
            gallerySymbols: ["leaf.fill", "figure.walk", "tree.fill"],
            facilitySymbols: ["figure.roll", "arrow.up.and.down.circle.fill", "toilet"],
            elevatorDetails: [
                .init(symbol: "arrow.up.arrow.down", label: "Both floors"),
                .init(symbol: "door.left.hand.open", label: "Wide doors"),
                .init(symbol: "hand.raised.fill", label: "Call button"),
                .init(symbol: "speaker.wave.2.fill", label: "Audio cues")
            ],
            reviewsSummary: "Visitors praise the step-free main entrance and reliable elevators. Restrooms are spacious; some note evening lighting could be brighter near the south gate.",
            grade: .accessible
        ),
        Place(
            id: UUID(),
            name: "Central Library",
            category: "Building",
            distance: "0.8 mi",
            address: "Grove St, Civic Center",
            ratingLabel: "Good",
            summary: "Accessible lobby, elevators to every floor, and reserved seating near exits.",
            description: "Public library with ramped entry, tactile indicators at stairs, and accessible study rooms on levels 2–4.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7793, longitude: -122.4192),
            accentColor: Color(red: 0.20, green: 0.40, blue: 0.65),
            gallerySymbols: ["books.vertical.fill", "building.columns.fill", "chair.lounge.fill"],
            facilitySymbols: ["figure.roll", "arrow.up.and.down.circle.fill", "figure.stairs"],
            elevatorDetails: [
                .init(symbol: "arrow.up.arrow.down", label: "4 levels"),
                .init(symbol: "door.left.hand.open", label: "Auto doors"),
                .init(symbol: "hand.raised.fill", label: "Low buttons"),
                .init(symbol: "checkmark.circle.fill", label: "Staff help")
            ],
            reviewsSummary: "Elevators are consistent and staff are helpful. Crowding near the main desk can narrow clear paths during peak hours.",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(),
            name: "Harbor Cafe",
            category: "Restaurant",
            distance: "1.1 mi",
            address: "The Embarcadero, Pier 39",
            ratingLabel: "Good",
            summary: "Step-free patio seating and an accessible restroom near the entrance.",
            description: "Waterfront cafe with wide aisles, movable chairs, and a clearly marked accessible restroom.",
            coordinate: CLLocationCoordinate2D(latitude: 37.8080, longitude: -122.4177),
            accentColor: Color(red: 0.75, green: 0.40, blue: 0.20),
            gallerySymbols: ["cup.and.saucer.fill", "fork.knife", "water.waves"],
            facilitySymbols: ["figure.roll", "toilet", "table.furniture"],
            elevatorDetails: [
                .init(symbol: "1.circle", label: "Single level"),
                .init(symbol: "door.left.hand.open", label: "Wide entry"),
                .init(symbol: "arrow.up.forward", label: "Patio ramp"),
                .init(symbol: "lightbulb.fill", label: "Bright rooms")
            ],
            reviewsSummary: "Patio is easy to navigate. Indoor tables can feel tight on weekends; ask staff for the corner booth.",
            grade: .partiallyAccessible
        ),
        Place(
            id: UUID(),
            name: "Ridgeview Hotel",
            category: "Hotel",
            distance: "1.6 mi",
            address: "Folsom St, SoMa",
            ratingLabel: "Excellent",
            summary: "Accessible rooms, lobby elevator bank, and step-free drop-off.",
            description: "Hotel with multiple accessible guest rooms, roll-in showers on request, and elevators serving all floors.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7879, longitude: -122.4075),
            accentColor: Color(red: 0.45, green: 0.30, blue: 0.55),
            gallerySymbols: ["bed.double.fill", "building.2.fill", "door.garage.closed"],
            facilitySymbols: ["figure.roll", "arrow.up.and.down.circle.fill", "shower.fill"],
            elevatorDetails: [
                .init(symbol: "arrow.up.arrow.down", label: "All floors"),
                .init(symbol: "door.left.hand.open", label: "Extra wide"),
                .init(symbol: "hand.raised.fill", label: "Braille"),
                .init(symbol: "clock.fill", label: "24/7 lobby")
            ],
            reviewsSummary: "Accessible rooms are well equipped. Elevators are quick; valet drop-off includes a curb cut.",
            grade: .accessible
        ),
        Place(
            id: UUID(),
            name: "Lakeside Trail",
            category: "Park",
            distance: "2.3 mi",
            address: "Sunset Blvd, Outer Sunset",
            ratingLabel: "Fair",
            summary: "Mostly paved loop with one steep section and limited restrooms.",
            description: "Scenic trail with a paved north loop. South spur has a grade that may challenge some manual wheelchair users.",
            coordinate: CLLocationCoordinate2D(latitude: 37.7694, longitude: -122.4862),
            accentColor: Color(red: 0.30, green: 0.50, blue: 0.45),
            gallerySymbols: ["tree.fill", "figure.walk", "bird.fill"],
            facilitySymbols: ["figure.roll", "binoculars.fill", "toilet"],
            elevatorDetails: [
                .init(symbol: "road.lanes", label: "Paved north"),
                .init(symbol: "arrow.up.right", label: "Steep south"),
                .init(symbol: "mappin.and.ellipse", label: "Rest stops"),
                .init(symbol: "drop.fill", label: "Water fountains")
            ],
            reviewsSummary: "North loop is smooth and popular. Plan around the steep south spur; restrooms are only near the main lot.",
            grade: .notAccessible
        )
    ]
}
