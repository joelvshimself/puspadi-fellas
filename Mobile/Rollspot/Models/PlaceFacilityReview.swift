import Foundation
import Shared

extension FacilityKind {
    init(shared kind: Shared.FacilityKind) {
        switch kind {
        case .entrance: self = .entrance
        case .elevator: self = .elevator
        case .toilet: self = .toilet
        }
    }

    var shared: Shared.FacilityKind {
        switch self {
        case .entrance: .entrance
        case .elevator: .elevator
        case .toilet: .toilet
        }
    }
}

/// Reviews in the current data model are always authored by the community.
enum ReviewProvenance: String, Hashable {
    case community

    init(rawValueOrCommunity raw: String?) {
        self = .community
    }

    /// Always nil — provenance is tracked in the database but no longer
    /// surfaced as a badge on the review card.
    var badgeLabel: String? { nil }
}

/// One community review row for a specific facility at a place.
struct PlaceFacilityReview: Identifiable, Hashable {
    let id: UUID
    let reviewId: UUID
    let kind: FacilityKind
    let createdAt: Date
    let bodyText: String
    let providedTags: [String]
    let photoURLs: [String]
    /// Per-photo captions, parallel to `photoURLs` (same index order).
    let photoCaptions: [String]
    /// Display-safe reviewer identity joined by the Worker.
    ///
    /// `reviewerName` is a PSEUDONYM unless the account opted into showing its
    /// real name. It is stable per account, so
    /// a reader can recognise a contributor across places.
    var reviewerName: String? = nil
    var reviewerRole: String? = nil
    var reviewerAvatarURL: URL? = nil
    /// True when `reviewerName` is a handle rather than a person's real name.
    /// Drives the small "handle" marker on the card — a made-up name presented
    /// with no qualifier reads as a real one.
    var reviewerIsPseudonym: Bool = false
    var provenance: ReviewProvenance = .community
    var sourceURL: URL? = nil

    /// What to put where a reviewer's name goes.
    ///
    var bylineName: String? {
        reviewerName
    }

    /// Keep reviewer cards compact and consistent: full legal names can be
    /// long, while the first two name components remain recognisable.
    var displayBylineName: String? {
        guard let bylineName else { return nil }
        let parts = bylineName.split(whereSeparator: \.isWhitespace)
        guard !parts.isEmpty else { return nil }
        return parts.prefix(2).joined(separator: " ")
    }

    var providedList: String {
        providedTags.joined(separator: ", ")
    }

    /// Whether the contributor actually wrote something. False for the many
    /// reviews that answered only the structured questions — those carry their
    /// content in `providedTags` and have no prose to quote.
    var hasBodyText: Bool {
        !bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Caption for the photo at `index` in `photoURLs`, if any.
    func caption(forPhotoAt index: Int) -> String? {
        guard index >= 0, index < photoCaptions.count else { return nil }
        let trimmed = photoCaptions[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Caption for a photo URL in this review, if any.
    func caption(forPhotoURL url: String) -> String? {
        guard let index = photoURLs.firstIndex(of: url) else { return nil }
        return caption(forPhotoAt: index)
    }

    /// `true` when `lhs` should appear above `rhs` in a newest-first list.
    static func isNewerFirst(_ lhs: PlaceFacilityReview, _ rhs: PlaceFacilityReview) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        // One submit fans out into several facility cards sharing a timestamp —
        // surface the last wizard step first (where photos usually land).
        if lhs.reviewId == rhs.reviewId {
            return facilityListRank(lhs.kind) < facilityListRank(rhs.kind)
        }
        return lhs.id.uuidString > rhs.id.uuidString
    }

    private static func facilityListRank(_ kind: FacilityKind) -> Int {
        switch kind {
        case .toilet: return 0
        case .elevator: return 1
        case .entrance: return 2
        }
    }
}

extension PlaceFacilityReview {
    /// Republishes a review the shared module already mapped, deduped and sorted.
    /// No rules here: only the types the SwiftUI views were written against.
    init(shared review: Shared.FacilityReview) {
        self.init(
            id: .stable(from: review.id),
            reviewId: UUID(uuidString: review.reviewId) ?? .stable(from: review.reviewId),
            kind: FacilityKind(shared: review.kind),
            createdAt: ReviewService.parseDate(review.createdAt),
            bodyText: review.bodyText,
            providedTags: review.providedTags,
            photoURLs: review.photoUrls,
            photoCaptions: review.photoCaptions,
            reviewerName: review.reviewerName,
            reviewerRole: review.reviewerRole,
            reviewerAvatarURL: review.reviewerAvatarUrl.flatMap(URL.init(string:)),
            reviewerIsPseudonym: review.reviewerIsPseudonym
        )
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
