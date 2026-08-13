import Foundation
import Supabase

/// Owner 3 Edge Functions — submit + read-back of community reviews.
///
/// `submit-accessibility-review` accepts the entrances/elevator/toilet
/// contribution payload, writes `reviews` + `review_entrances`, fans signals
/// into `accessibility_grade()`, and returns the live grade.
///
/// `place-review-photos` returns public photo URLs already stored on those
/// rows, labeled by facility, for Place Detail.
///
/// Photo upload: JPEG bytes go to the public `review-photos` Storage bucket
/// first; the resulting public URLs are sent as `photoUrls` on each facility
/// review. DB columns store those URL arrays (not blobs).
///
/// NOTE: JWT auth is intentionally off on the backend for device testing
/// (`user_id` is written as null via service_role) — see the Edge Function's
/// own TODO to re-enable auth before production.
final class ReviewService {
    static let shared = ReviewService()

    private static let reviewPhotosBucket = "review-photos"

    private let client: SupabaseClient

    /// The RPC-derived `grade` rows come back snake_case (best_value, ...),
    /// same as place-accessibility — see AccessibilityService's note.
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    struct SubmitResponse: Decodable {
        let status: String
        let reviewId: String
        let placeId: String
        let grade: [AccessibilityFeatureGrade]
    }

    private struct ReviewPhotosRequestBody: Encodable {
        let lat: Double
        let lng: Double
    }

    @discardableResult
    func submit(_ draft: ReviewDraft) async throws -> SubmitResponse {
        let photoUrls = try await uploadAllPhotos(for: draft)
        let payload = draft.buildSubmissionPayload(photoUrls: photoUrls)
        return try await client.functions.invoke(
            "submit-accessibility-review",
            options: FunctionInvokeOptions(body: payload),
            decoder: decoder
        )
    }

    /// Loads community review photos for the canonical place key derived from
    /// lat/lng (same `loc_{lat5}_{lng5}` as submit / place-accessibility).
    func fetchReviewPhotos(lat: Double, lng: Double) async throws -> PlaceReviewPhotosResponse {
        try await client.functions.invoke(
            "place-review-photos",
            options: FunctionInvokeOptions(body: ReviewPhotosRequestBody(lat: lat, lng: lng)),
            decoder: decoder
        )
    }

    // MARK: - Storage upload

    private func uploadAllPhotos(for draft: ReviewDraft) async throws -> ReviewPhotoURLMap {
        var map = ReviewPhotoURLMap()
        map.lobby = try await uploadPhotos(
            draft.lobby.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "lobby"
        )
        map.basement = try await uploadPhotos(
            draft.basement.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "basement"
        )
        map.elevator = try await uploadPhotos(
            draft.elevator.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "elevator"
        )
        map.toilet = try await uploadPhotos(
            draft.toilet.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "toilet"
        )
        return map
    }

    /// Uploads JPEGs to `reviews/{appleMapsId}/{facility}/{uuid}.jpg` and
    /// returns public URLs for the wire payload.
    private func uploadPhotos(
        _ photos: [ReviewPhotoDraft],
        appleMapsId: String,
        facility: String
    ) async throws -> [String] {
        guard !photos.isEmpty else { return [] }

        let folder = sanitizePathComponent(appleMapsId)
        let storage = client.storage.from(Self.reviewPhotosBucket)
        var urls: [String] = []
        urls.reserveCapacity(photos.count)

        for photo in photos {
            let path = "reviews/\(folder)/\(facility)/\(photo.id.uuidString).jpg"
            try await storage.upload(
                path,
                data: photo.jpegData,
                options: FileOptions(contentType: "image/jpeg", upsert: false)
            )
            let publicURL = try storage.getPublicURL(path: path)
            urls.append(publicURL.absoluteString)
        }
        return urls
    }

    /// Keeps Storage object keys URL-safe (Apple Maps ids can contain punctuation).
    private func sanitizePathComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.map { allowed.contains($0) ? Character($0) : "-" }
        let cleaned = String(scalars)
        return cleaned.isEmpty ? "unknown" : cleaned
    }
}
