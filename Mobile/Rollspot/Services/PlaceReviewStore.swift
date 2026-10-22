import Foundation
import Shared

/// The detail screen's source of truth. Loading, review mapping and the facility
/// rules all live in the shared `PlaceDetailModel`; this class only republishes
/// its result as Swift view types, so Android renders exactly the same data.
/// Which version of the page to show, straight from the shared `PlaceDetailState`.
enum PlaceDetailPhase: Equatable {
    case loading
    case loaded
    /// Shared `Empty`: no reviews and no community photos.
    case notReviewedYet
    /// The first load failed; nothing to show but a retry.
    case failed(String)
}

@MainActor
final class PlaceReviewStore: ObservableObject {
    @Published private(set) var phase: PlaceDetailPhase = .loading
    @Published private(set) var featureGrades: [AccessibilityFeatureGrade] = []
    /// Newest first, one verdict per person per facility (decided in shared).
    @Published private(set) var facilityReviews: [PlaceFacilityReview] = []
    @Published private(set) var reviewPhotos: [ReviewPhoto] = []
    @Published private(set) var allFacilityPhotos: [FacilityPhoto] = []
    @Published private(set) var streetImageURL: URL?
    @Published private(set) var imageAttribution: String?
    @Published private(set) var venuePhotos: [PlacePhoto] = []
    @Published private(set) var isLoading = false
    @Published private(set) var enrichResolved = false
    @Published private(set) var reviewPhotosLoadFailed = false
    @Published private(set) var reviewsResolved = false
    @Published private(set) var reviewsAttempted = false
    @Published private(set) var aiSummary: String?

    let place: Place
    private(set) var placeId: String
    private let model: Shared.PlaceDetailModel
    private var detail: Shared.PlaceDetail?
    private var reloadRequested = false

    init(place: Place) {
        self.place = place
        self.placeId = place.reviewPlaceId
        self.model = RollspotServices.sdk.placeDetailModel(placeKey: place.reviewPlaceId)
    }

    deinit { model.close() }

    func adoptPlaceId(_ canonicalId: String) {
        guard !canonicalId.isEmpty else { return }
        placeId = canonicalId
        model.adoptPlaceKey(canonical: canonicalId)
    }

    func load() async {
        if isLoading {
            reloadRequested = true
            return
        }
        isLoading = true
        repeat {
            reloadRequested = false
            await loadOnce()
        } while reloadRequested && !Task.isCancelled
        isLoading = false
    }

    /// A request that arrives during a load is coalesced into one more pass,
    /// ensuring a just-submitted review cannot be hidden by an older response.
    private func loadOnce() async {
        reviewPhotosLoadFailed = false
        reviewsAttempted = false
        defer {
            enrichResolved = true
            reviewsAttempted = true
        }

        let state: Shared.PlaceDetailState
        do {
            state = try await model.reload()
        } catch {
            return
        }
        switch onEnum(of: state) {
        case .loaded(let loaded):
            apply(loaded.detail)
            phase = .loaded
        case .empty(let empty):
            apply(empty.detail)
            phase = .notReviewedYet
        case .error(let failure):
            // The shared model keeps earlier content instead of erroring, so this
            // only happens when there is nothing to show yet: never "not reviewed".
            phase = .failed(failure.message)
        case .loading:
            break
        }
    }

    private func apply(_ detail: Shared.PlaceDetail) {
        self.detail = detail
        featureGrades = detail.grades.map {
            AccessibilityFeatureGrade(feature: $0.feature, bestValue: $0.bestValue, confidence: $0.confidence)
        }
        facilityReviews = detail.reviews.map { PlaceFacilityReview(shared: $0) }
        reviewsResolved = true
        reviewPhotosLoadFailed = detail.reviewPhotosLoadFailed
        if !detail.reviewPhotosLoadFailed {
            reviewPhotos = detail.reviewPhotos.map { ReviewPhoto(shared: $0) }
        }
        venuePhotos = detail.photos.map { PlacePhoto(shared: $0) }
        allFacilityPhotos = galleryPhotos(detail.gallery)
        streetImageURL = nil
        imageAttribution = nil
        aiSummary = PlaceAISummaryService.shared.summary(serverSummary: nil)
    }

    /// Cloudflare requests are refreshed explicitly after a local submission.
    /// We do not keep a background realtime channel open for every detail view.
    func startWatching() {}

    func reviews(for kind: FacilityKind) -> [PlaceFacilityReview] {
        facilityReviews.filter { $0.kind == kind }
    }

    func hasReviews(for kind: FacilityKind) -> Bool { !reviews(for: kind).isEmpty }
    func hasAnyReviews() -> Bool { !facilityReviews.isEmpty }

    func overviewState(for kind: FacilityKind) -> FacilityOverviewState {
        if isUnavailable(kind) { return .unavailable }
        if reviews(for: kind).isEmpty { return .empty }
        return .community
    }

    func isUnavailable(_ kind: FacilityKind) -> Bool {
        detail?.isUnavailable(kind: kind.shared) ?? false
    }

    func noteSnippets(for kind: FacilityKind, limit: Int = 3) -> [String] {
        detail?.noteSnippets(kind: kind.shared, limit: Int32(limit)) ?? []
    }

    func photos(for kind: FacilityKind) -> [ReviewPhoto] {
        (detail?.photosFor(kind: kind.shared) ?? []).map { ReviewPhoto(shared: $0) }
    }

    /// The Photos tab: the shared gallery (venue photos, then community photos), same as Android.
    private func galleryPhotos(_ gallery: [Shared.GalleryPhoto]) -> [FacilityPhoto] {
        gallery.enumerated().compactMap { index, photo in
            guard let url = URL(string: photo.url) else { return nil }
            return FacilityPhoto(
                id: .stable(from: "\(index)|\(photo.url)"),
                source: .remote(url),
                reviewId: facilityReviews.first { $0.photoURLs.contains(photo.url) }?.reviewId,
                caption: photo.caption
            )
        }
    }

    /// Tags the community confirmed for a facility, newest first, each once (shared rule).
    func providedTags(for kind: FacilityKind) -> [String] {
        detail?.providedTagsFor(kind: kind.shared) ?? []
    }

    func facilityPhotos(for kind: FacilityKind) -> [FacilityPhoto] {
        facilityPhotos(from: photos(for: kind))
    }

    private func facilityPhotos(from source: [ReviewPhoto]) -> [FacilityPhoto] {
        var seenURLs = Set<String>()
        return source
            .filter { seenURLs.insert($0.url).inserted }
            .enumerated()
            .compactMap { index, photo in
                guard let url = photo.imageURL else { return nil }
                let reviewId = facilityReviews.first { $0.photoURLs.contains(photo.url) }?.reviewId
                return FacilityPhoto(
                    id: .stable(from: "\(index)|\(photo.url)"),
                    source: .remote(url),
                    reviewId: reviewId,
                    caption: photo.trimmedCaption
                )
            }
    }

    /// The shared overall grade for the place page; nil until it has loaded. No Swift-only fallback,
    /// so iOS never shows a grade Android doesn't.
    var overallGrade: OverallAccessibility? {
        detail.map { OverallAccessibility($0.overall) }
    }
}
