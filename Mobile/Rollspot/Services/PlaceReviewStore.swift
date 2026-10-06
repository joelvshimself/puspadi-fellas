import Foundation

/// The detail screen's source of truth. Each load reads current community data
/// once; there is no second persistence cache to invalidate or reconcile.
@MainActor
final class PlaceReviewStore: ObservableObject {
    @Published private(set) var featureGrades: [AccessibilityFeatureGrade] = []
    @Published private(set) var facilityReviews: [PlaceFacilityReview] = [] {
        didSet { rebuildAllFacilityPhotos() }
    }
    @Published private(set) var reviewPhotos: [ReviewPhoto] = [] {
        didSet { rebuildAllFacilityPhotos() }
    }
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
    private var reloadRequested = false

    init(place: Place) {
        self.place = place
        self.placeId = place.reviewPlaceId
    }

    func adoptPlaceId(_ canonicalId: String) {
        guard !canonicalId.isEmpty else { return }
        placeId = canonicalId
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

        async let gradeResult = try? AccessibilityService.shared.enrich(placeId: placeId)
        async let reviewResult = loadFacilityReviews()
        async let photoResult = loadReviewPhotos()
        async let venueResult = PlacePhotoService.shared.photos(for: placeId)

        let gradeResponse = await gradeResult
        let reviews = await reviewResult
        let photos = await photoResult
        let venue = await venueResult
        featureGrades = gradeResponse?.grade ?? []
        facilityReviews = reviews ?? []
        reviewsResolved = reviews != nil
        if let photos {
            reviewPhotos = photos.photos
        }
        venuePhotos = venue
        streetImageURL = nil
        imageAttribution = nil
        aiSummary = await PlaceAISummaryService.shared.summary(
            for: place,
            featureGrades: featureGrades,
            serverSummary: nil
        )
    }

    private func loadFacilityReviews() async -> [PlaceFacilityReview]? {
        do {
            return try await ReviewService.shared.fetchPlaceReviews(placeId: placeId)
        } catch {
            if !Task.isCancelled { print("[PlaceReviewStore] Reviews failed: \(error)") }
            return nil
        }
    }

    private func loadReviewPhotos() async -> PlaceReviewPhotosResponse? {
        do {
            let response = try await ReviewService.shared.fetchReviewPhotos(placeId: placeId)
            reviewPhotosLoadFailed = false
            return response
        } catch {
            reviewPhotosLoadFailed = true
            return nil
        }
    }

    /// Cloudflare requests are refreshed explicitly after a local submission.
    /// We do not keep a background realtime channel open for every detail view.
    func startWatching() {}

    func reviews(for kind: FacilityKind) -> [PlaceFacilityReview] {
        facilityReviews
            .filter { $0.kind == kind }
            .sorted { PlaceFacilityReview.isNewerFirst($0, $1) }
    }

    func hasReviews(for kind: FacilityKind) -> Bool { !reviews(for: kind).isEmpty }
    func hasAnyReviews() -> Bool { !facilityReviews.isEmpty }

    func overviewState(for kind: FacilityKind) -> FacilityOverviewState {
        if isUnavailable(kind) { return .unavailable }
        if reviews(for: kind).isEmpty { return .empty }
        return .community
    }

    func isUnavailable(_ kind: FacilityKind) -> Bool {
        switch kind {
        case .elevator, .toilet:
            facilityReviews.contains { row in
                row.kind == kind && row.providedTags.contains("NOT AVAILABLE")
            }
        case .entrance:
            false
        }
    }

    func noteSnippets(for kind: FacilityKind, limit: Int = 3) -> [String] {
        reviews(for: kind)
            .filter(\.hasBodyText)
            .prefix(limit)
            .map(\.firstSentence)
            .filter { !$0.isEmpty }
    }

    func photos(for kind: FacilityKind) -> [ReviewPhoto] {
        reviewPhotos.filter { photo in
            switch kind {
            case .entrance:
                let facility = photo.facility.lowercased()
                return facility.contains("lobby") || facility.contains("basement")
                    || facility.contains("entrance") || facility.contains("exit")
            case .elevator:
                return photo.facility.lowercased().contains("elevator")
            case .toilet:
                return photo.facility.lowercased().contains("toilet")
            }
        }
    }

    private func rebuildAllFacilityPhotos() {
        allFacilityPhotos = facilityPhotos(from: reviewPhotos)
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

    var overallGrade: OverallAccessibility? {
        let collapsed = collapseAccessibility(featureGrades)
        return collapsed == .noData ? (place.grade ?? .noData) : collapsed
    }
}
