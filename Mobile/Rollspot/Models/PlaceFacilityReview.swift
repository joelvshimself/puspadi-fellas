import Foundation

/// Where a review came from. Mirrors the `review_provenance` enum in Postgres.
enum ReviewProvenance: String, Hashable {
    /// Written by a person using the app. The default, and the only value
    /// submit-accessibility-review ever writes.
    case community
    /// Brought in from an external dataset.
    case imported
    /// Derived from OpenStreetMap tags.
    case osm

    init(rawValueOrCommunity raw: String?) {
        self = ReviewProvenance(rawValue: raw ?? "") ?? .community
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
    /// Display-safe reviewer identity, joined server-side by the
    /// `place-reviews` Edge Function (profiles are RLS-locked to their owner,
    /// so the client can never read them directly). All nil for legacy rows
    /// written before auth.
    ///
    /// `reviewerName` is a PSEUDONYM unless the account opted into showing its
    /// real name — see the pseudonyms migration. It is stable per account, so
    /// a reader can recognise a contributor across places.
    var reviewerName: String? = nil
    var reviewerRole: String? = nil
    var reviewerAvatarURL: URL? = nil
    /// True when `reviewerName` is a handle rather than a person's real name.
    /// Drives the small "handle" marker on the card — a made-up name presented
    /// with no qualifier reads as a real one.
    var reviewerIsPseudonym: Bool = false
    /// Who authored the underlying review: a person using the app, or an
    /// import from a data source. Anything but `.community` is labelled on the
    /// card, because a machine-derived claim about a ramp must never be shown
    /// as somebody's first-hand report of one.
    var provenance: ReviewProvenance = .community
    /// For an imported row, the page the claim was read on. Shown as the
    /// byline and opened on tap — quoting somebody else's words without
    /// pointing at them is the part that would not be defensible.
    var sourceURL: URL? = nil

    /// What to put where a reviewer's name goes.
    ///
    /// An imported row has no author in the app, and letting it fall through
    /// to "Community" would credit a stranger's aside on a review site to this
    /// app's contributors. The host is both the honest answer and the useful
    /// one — a reader can weigh "tripadvisor.com" for themselves.
    var bylineName: String? {
        if provenance != .community {
            return sourceURL?.host?.replacingOccurrences(of: "www.", with: "")
        }
        return reviewerName
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

    /// Merges facility slices from the same DB review into one card for the
    /// Reviews tab. `mapReviews` fans one submission into elevator / toilet /
    /// entrance rows; grouping restores one card per contributor action.
    static func groupedByReviewId(_ reviews: [PlaceFacilityReview]) -> [PlaceFacilityReview] {
        var groups: [UUID: [PlaceFacilityReview]] = [:]
        var order: [UUID] = []

        for review in reviews {
            if groups[review.reviewId] == nil {
                order.append(review.reviewId)
                groups[review.reviewId] = []
            }
            groups[review.reviewId]?.append(review)
        }

        return order.map { reviewId in
            let slices = groups[reviewId]!
            let primary = slices.max(by: { $0.createdAt < $1.createdAt })!

            var photoURLs: [String] = []
            var photoCaptions: [String] = []
            for slice in slices {
                for index in slice.photoURLs.indices {
                    photoURLs.append(slice.photoURLs[index])
                    let caption = index < slice.photoCaptions.count
                        ? slice.photoCaptions[index]
                        : ""
                    photoCaptions.append(caption)
                }
            }

            var seenTags = Set<String>()
            var providedTags: [String] = []
            for slice in slices {
                for tag in slice.providedTags where seenTags.insert(tag).inserted {
                    providedTags.append(tag)
                }
            }

            let bodyParts = slices
                .map { $0.bodyText.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let bodyText = bodyParts.joined(separator: "\n")

            return PlaceFacilityReview(
                id: reviewId,
                reviewId: reviewId,
                kind: slices.first!.kind,
                createdAt: primary.createdAt,
                bodyText: bodyText,
                providedTags: providedTags,
                photoURLs: photoURLs,
                photoCaptions: photoCaptions,
                reviewerName: primary.reviewerName,
                reviewerRole: primary.reviewerRole,
                reviewerAvatarURL: primary.reviewerAvatarURL,
                reviewerIsPseudonym: primary.reviewerIsPseudonym,
                provenance: primary.provenance,
                sourceURL: primary.sourceURL
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
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
