import Foundation

private actor ReviewMutationGate {
    private var active: Set<String> = []

    func begin(_ key: String) -> Bool { active.insert(key).inserted }
    func end(_ key: String) { active.remove(key) }
}

private struct ReviewMutationInProgress: LocalizedError {
    var errorDescription: String? { "This review is already being saved." }
}

/// Submit and read back community reviews through the Cloudflare API.
/// JPEG data is uploaded to R2 first; D1 then stores normalized photo metadata
/// and structured facility answers under the authenticated user.
final class ReviewService {
    static let shared = ReviewService()

    private let client = CloudflareAPIClient.shared
    private let mutationGate = ReviewMutationGate()

    private init() {
    }

    private struct UploadResponse: Decodable {
        let url: String
    }

    struct SubmitResponse: Decodable {
        let status: String
        let reviewId: String
        let placeId: String
        let grade: [AccessibilityFeatureGrade]
    }

    struct MyReviewsResponse: Decodable {
        let status: String
        let userName: String?
        let userRole: String?
        let profileImageUrl: String?
        let reviews: [MyReviewItem]
    }

    struct MyReviewItem: Decodable, Identifiable {
        let id: UUID
        let placeId: String
        let placeName: String
        let createdAt: String
        let reviewText: String
        let providedFeatures: [String]
        let photoUrls: [String]
        let photoCaptions: [String]

        var photoURLs: [URL] {
            photoUrls.compactMap(URL.init(string:))
        }

        var facilityPhotos: [FacilityPhoto] {
            photoUrls.enumerated().compactMap { index, urlString in
                guard let url = URL(string: urlString) else { return nil }
                let caption = index < photoCaptions.count ? photoCaptions[index] : nil
                return FacilityPhoto(source: .remote(url), caption: caption)
            }
        }
    }

    @discardableResult
    func submit(_ draft: ReviewDraft) async throws -> SubmitResponse {
        let mutationKey = draft.submissionId.uuidString
        guard await mutationGate.begin(mutationKey) else { throw ReviewMutationInProgress() }
        print("[ReviewService] Submitting review for place \(draft.placeId)…")
        do {
            let photoUrls = try await uploadAllPhotos(for: draft)
            let payload = draft.buildSubmissionPayload(photoUrls: photoUrls)
            let response: SubmitResponse = try await client.post(
                ["v1", "reviews"],
                body: payload,
                authenticated: true
            )
            await mutationGate.end(mutationKey)
            print("[ReviewService] Review submitted successfully — reviewId: \(response.reviewId), placeId: \(response.placeId)")
            return response
        } catch {
            await mutationGate.end(mutationKey)
            print("[ReviewService] Review submission FAILED: \(error)")
            throw error
        }
    }

    /// Uploads gallery photos for one facility and persists via submit-accessibility-review.
    func submitGalleryPhotos(place: Place, facility: FacilityKind, localPhotos: [FacilityPhoto]) async throws {
        let mutationKey = "gallery:\(place.reviewPlaceId):\(facility.rawValue)"
        guard await mutationGate.begin(mutationKey) else { throw ReviewMutationInProgress() }
        defer { Task { await mutationGate.end(mutationKey) } }
        let jpegPhotos: [ReviewPhotoDraft] = localPhotos.compactMap { photo in
            guard case .local(let image) = photo.source,
                  let data = image.jpegData(compressionQuality: ReviewNoteDraft.jpegQuality)
            else { return nil }
            return ReviewPhotoDraft(
                image: image,
                jpegData: data,
                caption: photo.caption ?? ""
            )
        }
        guard !jpegPhotos.isEmpty else { return }

        let draft = ReviewDraft(placeId: place.reviewPlaceId, coordinate: place.coordinate, name: place.name)
        var urlMap = ReviewPhotoURLMap()

        // Photos only — no facility answers. This used to set
        // `elevator.exists = true` / `toilet.hasDisabledToilet = true` so the
        // review "had something", but the backend derives grade signals from
        // those flags: adding a toilet photo silently graded the toilet
        // accessible. A review whose facility fields are all null still
        // carries its photoUrls and contributes no grade signal.
        switch facility {
        case .entrance:
            draft.lobby.review.photos = jpegPhotos
            (urlMap.lobby, urlMap.lobbyCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                placeId: draft.placeId,
                facility: "lobby"
            )
        case .elevator:
            draft.elevator.review.photos = jpegPhotos
            (urlMap.elevator, urlMap.elevatorCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                placeId: draft.placeId,
                facility: "elevator"
            )
        case .toilet:
            draft.toilet.review.photos = jpegPhotos
            (urlMap.toilet, urlMap.toiletCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                placeId: draft.placeId,
                facility: "toilet"
            )
        }

        let payload = draft.buildSubmissionPayload(photoUrls: urlMap)
        let _: SubmitResponse = try await client.post(
            ["v1", "reviews"],
            body: payload,
            authenticated: true
        )
    }


    /// Realtime updates are intentionally absent; screens reload after local mutations.
    func watchReviewInserts(placeId: String) -> AsyncStream<Void> {
        AsyncStream { $0.finish() }
    }

    // MARK: - Storage upload

    private func uploadAllPhotos(for draft: ReviewDraft) async throws -> ReviewPhotoURLMap {
        var map = ReviewPhotoURLMap()
        (map.lobby, map.lobbyCaptions) = try await uploadPhotosWithCaptions(
            draft.lobby.review.photos,
            placeId: draft.placeId,
            facility: "lobby"
        )
        (map.basement, map.basementCaptions) = try await uploadPhotosWithCaptions(
            draft.basement.review.photos,
            placeId: draft.placeId,
            facility: "basement"
        )
        (map.elevator, map.elevatorCaptions) = try await uploadPhotosWithCaptions(
            draft.elevator.review.photos,
            placeId: draft.placeId,
            facility: "elevator"
        )
        (map.toilet, map.toiletCaptions) = try await uploadPhotosWithCaptions(
            draft.toilet.review.photos,
            placeId: draft.placeId,
            facility: "toilet"
        )
        return map
    }

    private func uploadPhotosWithCaptions(
        _ photos: [ReviewPhotoDraft],
        placeId: String,
        facility: String
    ) async throws -> ([String], [String]) {
        let urls = try await uploadPhotos(photos, placeId: placeId, facility: facility)
        let captions = photos.map {
            $0.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (urls, captions)
    }

    /// Uploads JPEGs for `placeId`/`facility` (one object per photo UUID) and
    /// returns public URLs for the wire payload.
    private func uploadPhotos(
        _ photos: [ReviewPhotoDraft],
        placeId: String,
        facility: String
    ) async throws -> [String] {
        guard !photos.isEmpty else { return [] }

        var urls: [String] = []
        urls.reserveCapacity(photos.count)

        for photo in photos {
            let response: UploadResponse = try await client.putData(
                ["v1", "media", "review-photos", placeId, facility, photo.id.uuidString],
                data: photo.jpegData,
                contentType: "image/jpeg"
            )
            urls.append(response.url)
        }
        return urls
    }

    /// Fetches reviews authored by the signed-in user.
    func fetchMyReviews() async throws -> MyReviewsResponse {
        try await client.get(["v1", "me", "reviews"], authenticated: true)
    }

    /// Deletes the signed-in user's review and its photos.
    func deleteMyReview(id: UUID) async throws {
        try await client.delete(["v1", "reviews", id.uuidString])
    }

    static func profileDateLabel(_ createdAt: String) -> String {
        listDateLabel(from: createdAt)
    }

    static func listDateLabel(from date: Date) -> String {
        listDateFormatter.string(from: date)
    }

    static func listDateLabel(from iso8601: String) -> String {
        listDateLabel(from: parseDate(iso8601))
    }

    private static let listDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.dateFormat = "d MMM yyyy"
        return formatter
    }()

    // MARK: - ISO dates

    private static let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let isoFormatterFallback: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    /// Parses the API's ISO-8601 timestamps for display. Review mapping itself lives
    /// in Mobile/shared (`mapPlaceReviews`).
    static func parseDate(_ value: String) -> Date {
        isoFormatter.date(from: value) ?? isoFormatterFallback.date(from: value) ?? Date()
    }
}
