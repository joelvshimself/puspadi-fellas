import Foundation

/// Mock-only data backing the demo "Place Details / Gallery / My Review"
/// screens (Views/Detail/Mock, Views/Gallery/Mock). Deliberately separate
/// from `Place`/`ReviewPhoto` — those are shaped for the live Supabase/
/// MapKit pipeline (coordinates, decodable backend payloads), and forcing
/// fake versions of that just to draw a mockup screen adds no value.
/// No backend calls anywhere in this file — static demo content only.

/// Which of the 3 Figma-mockup states the demo Place Details screen renders.
/// A single view branches on this rather than 3 separate view files, driven
/// by a dev-only state cycler (see MockPlaceDetailView).
enum PlaceDetailDemoState: String, CaseIterable, Identifiable {
    case noReview
    case notYetReviewed
    case reviewedByMe

    var id: String { rawValue }

    var label: String {
        switch self {
        case .noReview: "No Review"
        case .notYetReviewed: "Default"
        case .reviewedByMe: "Reviewed"
        }
    }
}

/// One row in the Facilities section (Entrance / Elevator / Toilet).
struct MockFacility: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let iconAssetName: String
    let tags: [MockTag]
    /// Non-nil renders this instead of the tag list (e.g. Toilet's
    /// "doesn't have an accessible toilet yet" state).
    let emptyStateText: String?
}

/// Icon + label pill used both on Facility cards and the My Review
/// "What provided" section.
struct MockTag: Identifiable, Hashable {
    let id = UUID()
    let label: String

    static func == (lhs: MockTag, rhs: MockTag) -> Bool { lhs.label == rhs.label }
    func hash(into hasher: inout Hasher) { hasher.combine(label) }
}

/// One photo in the Gallery grid / My Review photo strip.
struct MockPhoto: Identifiable {
    let id = UUID()
    /// Asset catalog name to render; falls back to a plain tinted
    /// placeholder with a system-image glyph when nil (we only have 4 real
    /// PNGs, so most grid cells reuse them or fall back).
    let assetName: String?
    let systemImageFallback: String
    /// "entrance" / "elevator" / "toilet" — used for Gallery's filter tabs.
    let facility: String
}

/// Backing content for the "My Review" screen.
struct MockReview {
    let reviewedDateLabel: String
    let facilityTabs: [MockFacility]
    let notes: String
}

/// Static Park23 Mall demo content, shared by every mock screen so they
/// stay in sync with each other.
enum MockData {
    static let placeName = "Park23 Mall"

    static let entranceTags: [MockTag] = [
        MockTag(label: "RAMP"),
        MockTag(label: "HANDRAIL"),
        MockTag(label: "AUTOMATIC DOORS"),
    ]
    static let entranceExtraCount = 5

    static let elevatorTags: [MockTag] = [
        MockTag(label: "WIDE ENTRANCE"),
        MockTag(label: "REACHABLE BUTTONS"),
    ]

    static let facilities: [MockFacility] = [
        MockFacility(
            key: "entrance",
            title: "Entrance",
            iconAssetName: "Entrance Asset",
            tags: entranceTags,
            emptyStateText: nil
        ),
        MockFacility(
            key: "elevator",
            title: "Elevator",
            iconAssetName: "Elevator Asset",
            tags: elevatorTags,
            emptyStateText: nil
        ),
        MockFacility(
            key: "toilet",
            title: "Toilet",
            iconAssetName: "Toilet Asset",
            tags: [],
            emptyStateText: "This place doesn't has an accessible toilet yet"
        ),
    ]

    /// Gallery grid content — reuses the 4 real PNGs we have plus SF Symbol
    /// placeholders for the remaining cells so the masonry layout has
    /// enough items to demonstrate every row shape.
    static let photos: [MockPhoto] = [
        MockPhoto(assetName: "Park23 Image", systemImageFallback: "photo", facility: "entrance"),
        MockPhoto(assetName: "Park23 Image", systemImageFallback: "photo", facility: "entrance"),
        MockPhoto(assetName: "Park23 Image", systemImageFallback: "photo", facility: "entrance"),
        MockPhoto(assetName: nil, systemImageFallback: "arrow.up.arrow.down.circle.fill", facility: "elevator"),
        MockPhoto(assetName: nil, systemImageFallback: "arrow.up.arrow.down.circle.fill", facility: "elevator"),
        MockPhoto(assetName: nil, systemImageFallback: "toilet.fill", facility: "toilet"),
        MockPhoto(assetName: nil, systemImageFallback: "toilet.fill", facility: "toilet"),
        MockPhoto(assetName: "Park23 Image", systemImageFallback: "photo", facility: "entrance"),
        MockPhoto(assetName: nil, systemImageFallback: "arrow.up.arrow.down.circle.fill", facility: "elevator"),
        MockPhoto(assetName: nil, systemImageFallback: "toilet.fill", facility: "toilet"),
    ]

    static let reviewFacilityTabs: [MockFacility] = [
        MockFacility(
            key: "entrance",
            title: "Entrance",
            iconAssetName: "Entrance Asset",
            tags: [
                MockTag(label: "RAMP"),
                MockTag(label: "HANDRAIL"),
                MockTag(label: "AUTOMATIC DOORS"),
                MockTag(label: "MANUAL DOORS"),
                MockTag(label: "SECURITY ASSISTANCE"),
            ],
            emptyStateText: nil
        ),
        MockFacility(
            key: "elevator",
            title: "Elevator",
            iconAssetName: "Elevator Asset",
            tags: elevatorTags,
            emptyStateText: nil
        ),
        MockFacility(
            key: "toilet",
            title: "Toilet",
            iconAssetName: "Toilet Asset",
            tags: [],
            emptyStateText: "This place doesn't has an accessible toilet yet"
        ),
    ]

    static let review = MockReview(
        reviewedDateLabel: "26 January 2026",
        facilityTabs: reviewFacilityTabs,
        notes: "The entrance is quite hard to find. When I went there, there's a lot of stairs and it is very hard too see the signage and need to ask the security."
    )
}
