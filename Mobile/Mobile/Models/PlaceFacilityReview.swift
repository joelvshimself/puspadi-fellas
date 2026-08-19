import Foundation

/// One community review row for a specific facility at a place.
struct PlaceFacilityReview: Identifiable, Hashable {
    let id: UUID
    let reviewId: UUID
    let kind: FacilityKind
    let createdAt: Date
    let bodyText: String
    let providedTags: [String]
    let photoURLs: [String]

    var providedList: String {
        providedTags.joined(separator: ", ")
    }

    /// First sentence of the review body for notes snippets.
    var firstSentence: String {
        PlaceFacilityReview.firstSentence(from: bodyText)
    }

    static func firstSentence(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        let terminators = CharacterSet(charactersIn: ".!?")
        if let range = trimmed.rangeOfCharacter(from: terminators) {
            let end = trimmed.index(after: range.lowerBound)
            return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }
}

/// The review state of a single facility on the place-detail card.
enum FacilityCardState {
    /// No community reviews have been submitted for this facility yet.
    case notReviewed
    /// At least one review exists; carries the tags from the most recent one.
    case reviewed([String])
    /// Reviewers marked this facility as not available at this place.
    case unavailable
}

/// Card model for the place-detail facilities section.
struct FacilityCardModel: Identifiable {
    let id: String
    let key: String
    let title: String
    let iconAssetName: String
    let state: FacilityCardState

    var kind: FacilityKind? { FacilityKind(rawValue: key) }
}

extension FacilityCardModel {
    @MainActor
    static func cards(from store: PlaceReviewStore) -> [FacilityCardModel] {
        [
            makeCard(kind: .entrance, store: store),
            makeCard(kind: .elevator, store: store),
            makeCard(kind: .toilet, store: store),
        ]
    }

    @MainActor
    private static func makeCard(kind: FacilityKind, store: PlaceReviewStore) -> FacilityCardModel {
        let icon: String
        switch kind {
        case .entrance: icon = "Entrance Asset"
        case .elevator: icon = "Elevator Asset"
        case .toilet: icon = "Toilet Asset"
        }

        let cardState: FacilityCardState
        if store.isUnavailable(kind) {
            cardState = .unavailable
        } else {
            let reviews = store.reviews(for: kind)
            if reviews.isEmpty {
                cardState = .notReviewed
            } else {
                cardState = .reviewed(reviews.first?.providedTags ?? [])
            }
        }

        return FacilityCardModel(
            id: kind.rawValue,
            key: kind.rawValue,
            title: kind.title,
            iconAssetName: icon,
            state: cardState
        )
    }
}
