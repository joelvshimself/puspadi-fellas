import Foundation

/// Mock-only data for `MockMyReviewView` (legacy demo screen).
/// Live place detail uses `PlaceReviewStore` + Supabase — see MockPlaceDetailView.
struct MockTag: Identifiable, Hashable {
    let id = UUID()
    let label: String

    static func == (lhs: MockTag, rhs: MockTag) -> Bool { lhs.label == rhs.label }
    func hash(into hasher: inout Hasher) { hasher.combine(label) }
}

struct MockFacility: Identifiable {
    let id = UUID()
    let key: String
    let title: String
    let iconAssetName: String
    let tags: [MockTag]
    let emptyStateText: String?
}

struct MockPhoto: Identifiable {
    let id = UUID()
    let assetName: String?
    let systemImageFallback: String
    let facility: String
}

struct MockReview {
    let reviewedDateLabel: String
    let facilityTabs: [MockFacility]
    let notes: String
}

enum MockData {
    static let placeName = "Park23 Mall"

    static let photos: [MockPhoto] = [
        MockPhoto(assetName: "Park23 Image", systemImageFallback: "photo", facility: "entrance"),
        MockPhoto(assetName: nil, systemImageFallback: "arrow.up.arrow.down.circle.fill", facility: "elevator"),
        MockPhoto(assetName: nil, systemImageFallback: "toilet.fill", facility: "toilet"),
    ]

    static let review = MockReview(
        reviewedDateLabel: "26 January 2026",
        facilityTabs: [
            MockFacility(
                key: "entrance",
                title: "Entrance",
                iconAssetName: "Entrance Asset",
                tags: [
                    MockTag(label: "RAMP"),
                    MockTag(label: "HANDRAIL"),
                    MockTag(label: "AUTOMATIC DOORS"),
                ],
                emptyStateText: nil
            ),
            MockFacility(
                key: "elevator",
                title: "Elevator",
                iconAssetName: "Elevator Asset",
                tags: [
                    MockTag(label: "WIDE ENTRANCE"),
                    MockTag(label: "REACHABLE BUTTONS"),
                ],
                emptyStateText: nil
            ),
            MockFacility(
                key: "toilet",
                title: "Toilet",
                iconAssetName: "Toilet Asset",
                tags: [],
                emptyStateText: "This place doesn't has an accessible toilet yet"
            ),
        ],
        notes: "The entrance is quite hard to find. When I went there, there's a lot of stairs and it is very hard too see the signage and need to ask the security."
    )
}
