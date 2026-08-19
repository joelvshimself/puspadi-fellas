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
    @Published private(set) var isLoading = false
    @Published private(set) var enrichResolved = false
    @Published private(set) var reviewPhotosLoadFailed = false

    let place: Place
    let placeId: String

    private var watchTask: Task<Void, Never>?
    private var loadGeneration = 0

    init(place: Place) {
        self.place = place
        self.placeId = Place.canonicalPlaceId(from: place.coordinate)
    }

    deinit {
        watchTask?.cancel()
    }

    func load() async {
        loadGeneration += 1
        let generation = loadGeneration
        isLoading = true
        reviewPhotosLoadFailed = false
        defer {
            if generation == loadGeneration {
                isLoading = false
                enrichResolved = true
            }
        }

        async let enriched = try? AccessibilityService.shared.enrich(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            name: place.name
        )
        async let reviews = loadFacilityReviews()

        let (enrichResponse, reviewRows, photoResponse) = await (
            enriched,
            reviews,
            loadReviewPhotos()
        )

        guard generation == loadGeneration else {
            print("[PlaceReviewStore] Discarding stale refresh for \(placeId)")
            return
        }

        featureGrades = enrichResponse?.grade ?? []
        imageAttribution = enrichResponse?.place?.imageAttribution
        streetImageURL = enrichResponse?.place?.imageUrl.flatMap(URL.init(string:))
        if let photoResponse {
            reviewPhotos = photoResponse.photos
        }
        if let reviewRows {
            facilityReviews = reviewRows
            print("[PlaceReviewStore] Loaded \(reviewRows.count) facility review(s) for \(placeId)")
        }
    }

    private func loadFacilityReviews() async -> [PlaceFacilityReview]? {
        do {
            return try await ReviewService.shared.fetchPlaceReviews(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude
            )
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
                lng: place.coordinate.longitude
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

    func noteSnippets(for kind: FacilityKind, limit: Int = 3) -> [String] {
        reviews(for: kind)
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

    func facilityPhotos(for kind: FacilityKind) -> [FacilityPhoto] {
        photos(for: kind).compactMap { photo -> FacilityPhoto? in
            guard let url = photo.imageURL else { return nil }
            let reviewId = facilityReviews.first { review in
                review.photoURLs.contains(photo.url)
            }?.reviewId
            return FacilityPhoto(source: .remote(url), reviewId: reviewId)
        }
    }

    var overallGrade: OverallAccessibility? {
        if featureGrades.isEmpty { return place.grade ?? .noData }
        if featureGrades.contains(where: { $0.bestValue == "no" }) { return .notAccessible }
        if featureGrades.allSatisfy({ $0.bestValue == "yes" }) { return .accessible }
        return .partiallyAccessible
    }
}
