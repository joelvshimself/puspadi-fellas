import CoreLocation
import Foundation

/// Reactive source of truth for place-level grades, reviews, and photos.
@MainActor
final class PlaceReviewStore: ObservableObject {
    @Published private(set) var featureGrades: [AccessibilityFeatureGrade] = []
    @Published private(set) var facilityReviews: [PlaceFacilityReview] = []
    @Published private(set) var reviewPhotos: [ReviewPhoto] = []
    @Published private(set) var streetImageURL: URL?
    @Published private(set) var imageAttribution: String?
    /// Curated photographs of the venue itself (see PlacePhotoService).
    /// Preferred over the street-level image where they exist: a photo the
    /// venue publishes of its own frontage beats whatever Mapillary happened
    /// to drive past.
    @Published private(set) var venuePhotos: [PlacePhoto] = []
    @Published private(set) var isLoading = false
    @Published private(set) var enrichResolved = false
    @Published private(set) var reviewPhotosLoadFailed = false
    /// True once the reviews fetch has SUCCEEDED at least once. An empty
    /// `facilityReviews` only means "no reviews" when this is set — before
    /// that it may just mean the fetch failed, which must never render as
    /// the "Know something about the place?" empty state.
    @Published private(set) var reviewsResolved = false
    /// True once the reviews fetch has COMPLETED at least once, success or
    /// not. Until then the page is still loading — a cached grade makes
    /// `isLoading` false immediately, but rendering the tabs before the
    /// reviews land flashed empty cards for a second on every open.
    @Published private(set) var reviewsAttempted = false

    let place: Place
    /// Which place_id this venue actually lives under.
    ///
    /// Starts as the coordinate-derived guess and is replaced by the canonical
    /// id the moment enrich() reports one. They differ whenever MapKit handed
    /// us a drifted reading of a place the backend already knows — which is
    /// most of the time for map pins — and reviews, photos and cache
    /// invalidation all have to follow the canonical id, not the guess, or
    /// they address a row nothing else points at.
    private(set) var placeId: String

    private var watchTask: Task<Void, Never>?
    private var loadGeneration = 0
    /// Bounded so a place whose claim is stuck (a worker killed mid-flight
    /// holds it for REFRESH_CLAIM_TTL_MS) cannot turn into a polling loop.
    private var provisionalRetries = 0
    private static let maxProvisionalRetries = 2
    private var provisionalTask: Task<Void, Never>?

    init(place: Place) {
        self.place = place
        // A directory place already knows which row it is — no guess needed,
        // and no chance of addressing a neighbouring id while enrich() is
        // still in flight.
        self.placeId = place.directoryPlaceId ?? Place.canonicalPlaceId(from: place.coordinate)
    }

    deinit {
        watchTask?.cancel()
        provisionalTask?.cancel()
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        reviewPhotosLoadFailed = false

        // Publish the cached grade BEFORE awaiting anything. enrich() is only
        // one of three requests below, and they resolve together — so a place
        // opened before still sat on a spinner while the review and photo
        // calls finished, even though its grade was already on disk.
        if let cached = await PlaceCacheStore.shared.get(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            name: place.name
        ) {
            featureGrades = cached.grade ?? []
            imageAttribution = cached.place?.imageAttribution
            streetImageURL = cached.place?.imageUrl.flatMap(URL.init(string:))
            if let known = cached.place?.placeId { placeId = known }
            enrichResolved = true
        }

        // Only show loading if there is genuinely nothing to show yet.
        isLoading = featureGrades.isEmpty
        defer {
            if generation == loadGeneration {
                isLoading = false
                enrichResolved = true
            }
        }

        // enrich() runs FIRST rather than alongside the other two, because it
        // is what tells us the canonical place_id — and querying `reviews` for
        // the coordinate-derived guess returns nothing when the backend filed
        // them under a resolved id. It is a cache hit in the common case, so
        // this costs no real latency, and the grade above is already on screen.
        let enrichResponse = try? await AccessibilityService.shared.enrich(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            name: place.name,
            userInitiated: true
        )
        if let resolved = enrichResponse?.place?.placeId { placeId = resolved }

        guard generation == loadGeneration else {
            print("[PlaceReviewStore] Discarding stale refresh for \(placeId)")
            return
        }

        async let reviews = loadFacilityReviews(placeId: placeId)
        async let venue = PlacePhotoService.shared.photos(for: placeId)
        let (reviewRows, photoResponse, venueRows) = await (reviews, loadReviewPhotos(), venue)

        guard generation == loadGeneration else {
            print("[PlaceReviewStore] Discarding stale refresh for \(placeId)")
            return
        }

        reviewsAttempted = true
        venuePhotos = venueRows
        featureGrades = enrichResponse?.grade ?? []
        imageAttribution = enrichResponse?.place?.imageAttribution
        streetImageURL = enrichResponse?.place?.imageUrl.flatMap(URL.init(string:))
        if let photoResponse {
            reviewPhotos = photoResponse.photos
        }
        if let reviewRows {
            facilityReviews = reviewRows
            reviewsResolved = true
            print("[PlaceReviewStore] Loaded \(reviewRows.count) facility review(s) for \(placeId)")
        }

        scheduleProvisionalRefresh(for: enrichResponse)
    }

    /// The Edge Function answers before its background task has fetched OSM
    /// tags and downloaded the Mapillary photo, so the first look at a place
    /// legitimately has no image. Rather than leaving the screen empty until
    /// the user comes back, ask again once the work has had time to land.
    private func scheduleProvisionalRefresh(for response: PlaceAccessibilityResponse?) {
        guard response?.place?.refreshClaimedAt != nil else {
            provisionalRetries = 0
            return
        }
        guard provisionalRetries < Self.maxProvisionalRetries else { return }
        provisionalRetries += 1

        provisionalTask?.cancel()
        provisionalTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled, let self else { return }
            // The cached copy is the provisional one — drop it or enrich()
            // hands back the same image-less answer. Both keys: the response is
            // filed under the coordinate key we asked with and mirrored under
            // whatever canonical id the server resolved it to.
            await PlaceCacheStore.shared.remove(self.placeId)
            if let resolved = response?.place?.placeId, resolved != self.placeId {
                await PlaceCacheStore.shared.remove(resolved)
            }
            await self.load()
        }
    }

    private func loadFacilityReviews(placeId: String) async -> [PlaceFacilityReview]? {
        do {
            return try await ReviewService.shared.fetchPlaceReviews(placeId: placeId)
        } catch {
            print("[PlaceReviewStore] Facility review fetch FAILED for \(placeId): \(error)")
            return nil
        }
    }

    @discardableResult
    private func loadReviewPhotos() async -> PlaceReviewPhotosResponse? {
        do {
            let response = try await ReviewService.shared.fetchReviewPhotos(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude,
                name: place.name
            )
            reviewPhotosLoadFailed = false
            return response
        } catch {
            reviewPhotosLoadFailed = true
            return nil
        }
    }

    func startWatching() {
        watchTask?.cancel()
        watchTask = Task {
            for await _ in ReviewService.shared.watchReviewInserts(placeId: placeId) {
                // The reviews-table insert arrives before its review_entrances
                // child rows are committed by the Edge Function.
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { break }
                await PlaceCacheStore.shared.remove(placeId)
                await load()
            }
        }
    }

    func reviews(for kind: FacilityKind) -> [PlaceFacilityReview] {
        facilityReviews
            .filter { $0.kind == kind }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func hasReviews(for kind: FacilityKind) -> Bool {
        !reviews(for: kind).isEmpty
    }

    func hasAnyReviews() -> Bool {
        !facilityReviews.isEmpty
    }

    func overviewState(for kind: FacilityKind) -> FacilityOverviewState {
        if isUnavailable(kind) { return .unavailable }
        if reviews(for: kind).isEmpty { return .empty }
        return .community
    }

    func isUnavailable(_ kind: FacilityKind) -> Bool {
        switch kind {
        case .elevator:
            return facilityReviews.contains { row in
                row.kind == .elevator && row.providedTags.contains("NOT AVAILABLE")
            }
        case .toilet:
            return facilityReviews.contains { row in
                row.kind == .toilet && row.providedTags.contains("NOT AVAILABLE")
            }
        case .entrance:
            return false
        }
    }

    /// Opening sentences of the most recent reviews that actually say
    /// something, newest first.
    ///
    /// Filters BEFORE taking `limit`, not after. Most reviews answer only the
    /// structured questions, so slicing the newest three and then dropping the
    /// textless ones routinely left this empty while a real note sat fourth in
    /// the list. Nothing is synthesised to pad it out: if nobody has written
    /// about this facility the section says so, which is true and is also an
    /// invitation to be the first.
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
                let f = photo.facility.lowercased()
                return f.contains("lobby") || f.contains("basement") || f.contains("entrance") || f.contains("exit")
            case .elevator:
                return photo.facility.lowercased().contains("elevator")
            case .toilet:
                return photo.facility.lowercased().contains("toilet")
            }
        }
    }

    /// Every photo on this place, whatever facility it belongs to. The Photos
    /// tab no longer carries a facility selector, so filtering by one would
    /// silently hide most of what has been contributed.
    var allFacilityPhotos: [FacilityPhoto] {
        facilityPhotos(from: reviewPhotos)
    }

    func facilityPhotos(for kind: FacilityKind) -> [FacilityPhoto] {
        facilityPhotos(from: photos(for: kind))
    }

    private func facilityPhotos(from source: [ReviewPhoto]) -> [FacilityPhoto] {
        source.compactMap { photo -> FacilityPhoto? in
            guard let url = photo.imageURL else { return nil }
            let reviewId = facilityReviews.first { review in
                review.photoURLs.contains(photo.url)
            }?.reviewId
            return FacilityPhoto(
                source: .remote(url),
                reviewId: reviewId,
                caption: photo.trimmedCaption
            )
        }
    }

    var overallGrade: OverallAccessibility? {
        // Nothing known yet — keep whatever the pin already showed rather
        // than contradicting it with "no data".
        let collapsed = collapseAccessibility(featureGrades)
        return collapsed == .noData ? (place.grade ?? .noData) : collapsed
    }
}
