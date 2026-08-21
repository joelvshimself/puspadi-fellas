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
        client = SupabaseClientProvider.shared
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
        /// Same reason as the submission payload: without it the backend can
        /// only key on the raw coordinate, which is not stable per venue.
        let name: String?
    }

    @discardableResult
    func submit(_ draft: ReviewDraft) async throws -> SubmitResponse {
        print("[ReviewService] Submitting review for place \(draft.appleMapsId)…")
        let photoUrls = try await uploadAllPhotos(for: draft)
        let payload = draft.buildSubmissionPayload(photoUrls: photoUrls)
        do {
            let response: SubmitResponse = try await client.functions.invoke(
                "submit-accessibility-review",
                options: FunctionInvokeOptions(body: payload),
                decoder: decoder
            )
            print("[ReviewService] Review submitted successfully — reviewId: \(response.reviewId), placeId: \(response.placeId)")
            return response
        } catch {
            print("[ReviewService] Review submission FAILED: \(error)")
            throw error
        }
    }

    /// Uploads gallery photos for one facility and persists via submit-accessibility-review.
    func submitGalleryPhotos(place: Place, facility: FacilityKind, localPhotos: [FacilityPhoto]) async throws {
        let jpegPhotos: [ReviewPhotoDraft] = localPhotos.compactMap { photo in
            guard case .local(let image) = photo.source,
                  let data = image.jpegData(compressionQuality: ReviewNoteDraft.jpegQuality)
            else { return nil }
            return ReviewPhotoDraft(image: image, jpegData: data)
        }
        guard !jpegPhotos.isEmpty else { return }

        let draft = ReviewDraft(appleMapsId: place.id.uuidString, coordinate: place.coordinate, name: place.name)
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
            urlMap.lobby = try await uploadPhotos(jpegPhotos, appleMapsId: draft.appleMapsId, facility: "lobby")
        case .elevator:
            draft.elevator.review.photos = jpegPhotos
            urlMap.elevator = try await uploadPhotos(jpegPhotos, appleMapsId: draft.appleMapsId, facility: "elevator")
        case .toilet:
            draft.toilet.review.photos = jpegPhotos
            urlMap.toilet = try await uploadPhotos(jpegPhotos, appleMapsId: draft.appleMapsId, facility: "toilet")
        }

        let payload = draft.buildSubmissionPayload(photoUrls: urlMap)
        let _: SubmitResponse = try await client.functions.invoke(
            "submit-accessibility-review",
            options: FunctionInvokeOptions(body: payload),
            decoder: decoder
        )
    }

    /// Loads community review photos for the canonical place. The backend
    /// resolves (lat, lng, name) onto an existing place_id where it knows one,
    /// falling back to `loc_{lat4}_{lng4}` — same rule as submit and
    /// place-accessibility, so all three agree on which place this is.
    func fetchReviewPhotos(
        lat: Double,
        lng: Double,
        name: String? = nil
    ) async throws -> PlaceReviewPhotosResponse {
        try await NetworkRetry.run {
            try await client.functions.invoke(
                "place-review-photos",
                options: FunctionInvokeOptions(
                    body: ReviewPhotosRequestBody(lat: lat, lng: lng, name: name)
                ),
                decoder: decoder
            )
        }
    }

    /// Subscribes to new `reviews` rows for `placeId`. Yields on each insert so
    /// Place Detail can refresh grade + photos while the sheet is open.
    /// Cancelling the surrounding task removes the Realtime channel.
    func watchReviewInserts(placeId: String) -> AsyncStream<Void> {
        AsyncStream { continuation in
            let task = Task {
                // Unique suffix prevents Supabase from reusing a previously-subscribed
                // channel with the same topic name, which causes a "Cannot add
                // postgres_changes callbacks after subscribe()" error.
                let channel = client.channel("place-reviews-\(placeId)-\(UUID().uuidString)")
                defer {
                    Task { await client.removeChannel(channel) }
                }
                let inserts = channel.postgresChange(
                    InsertAction.self,
                    schema: "public",
                    table: "reviews",
                    filter: .eq("place_id", value: placeId)
                )
                do {
                    _ = try await channel.subscribeWithError()
                    for await _ in inserts {
                        if Task.isCancelled { break }
                        continuation.yield(())
                    }
                } catch {
                    print("Realtime subscription notice for \(placeId): \(error)")
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
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

    // MARK: - Direct DB Access

    struct DBReviewRow: Decodable {
        let id: UUID
        let placeId: String
        let notes: String?
        let createdAt: String
        let elevatorPhotoUrls: [String]?
        let toiletPhotoUrls: [String]?
    }

    /// Uploads a single JPEG image to Supabase Storage in review-photos bucket and returns public URL.
    func uploadPhoto(jpegData: Data, folderName: String = "uploads") async throws -> String {
        let storage = client.storage.from(Self.reviewPhotosBucket)
        let filename = "\(folderName)/\(UUID().uuidString).jpg"
        try await storage.upload(
            filename,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try storage.getPublicURL(path: filename)
        return publicURL.absoluteString
    }

    /// Fetches all submitted reviews from the Supabase `reviews` table.
    func fetchAllReviews() async throws -> [DBReviewRow] {
        try await client.from("reviews")
            .select("id, place_id, notes, created_at, elevator_photo_urls, toilet_photo_urls")
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    /// Fetches reviews authored by the signed-in user, including entrance children.
    func fetchMyReviews(userId: UUID) async throws -> [DBOwnedReviewRow] {
        try await client.from("reviews")
            .select("""
                id, place_id, created_at, notes,
                elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
                elevator_review_text, elevator_photo_urls,
                has_disabled_toilet, toilet_review_text, toilet_photo_urls,
                review_entrances(location, has_dropoff_ramp, has_rails, door_type, is_wide_enough, review_text, photo_urls)
            """)
            .eq("user_id", value: userId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }

    struct DBOwnedReviewRow: Decodable {
        let id: UUID
        let placeId: String
        let createdAt: String
        let notes: String?
        let elevatorExists: Bool?
        let elevatorWheelchairAccessible: Bool?
        let elevatorBlockers: [String]?
        let elevatorReviewText: String?
        let elevatorPhotoUrls: [String]?
        let hasDisabledToilet: Bool?
        let toiletReviewText: String?
        let toiletPhotoUrls: [String]?
        let reviewEntrances: [DBReviewEntranceRow]?

        var allPhotoURLs: [URL] {
            var urls: [URL] = []
            urls.append(contentsOf: (elevatorPhotoUrls ?? []).compactMap(URL.init(string:)))
            urls.append(contentsOf: (toiletPhotoUrls ?? []).compactMap(URL.init(string:)))
            for entrance in reviewEntrances ?? [] {
                urls.append(contentsOf: (entrance.photoUrls ?? []).compactMap(URL.init(string:)))
            }
            return urls
        }

        var providedTags: [String] {
            var tags: [String] = []
            for entrance in reviewEntrances ?? [] {
                tags.append(contentsOf: ReviewService.profileEntranceTags(from: entrance))
            }
            if elevatorExists == true { tags.append("Elevator") }
            if hasDisabledToilet == true { tags.append("Toilet") }
            var seen = Set<String>()
            return tags.filter { seen.insert($0).inserted }
        }

        var primaryNotes: String {
            if let notes, !notes.isEmpty { return notes }
            if let text = elevatorReviewText, !text.isEmpty { return text }
            if let text = toiletReviewText, !text.isEmpty { return text }
            if let text = reviewEntrances?.compactMap(\.reviewText).first(where: { !$0.isEmpty }) {
                return text
            }
            return "No review notes written."
        }
    }

    static func profileEntranceTags(from row: DBReviewEntranceRow) -> [String] {
        var tags: [String] = []
        if row.hasDropoffRamp == true { tags.append("Ramp") }
        if row.hasRails == true { tags.append("Handrail") }
        if row.doorType == "automatic" { tags.append("Automatic Doors") }
        if row.doorType == "manual" { tags.append("Manual Doors") }
        return tags
    }

    static func profileDateLabel(_ createdAt: String) -> String {
        let date = parseDate(createdAt)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yyyy"
        return formatter.string(from: date)
    }

    // MARK: - Place facility reviews

    struct DBReviewEntranceRow: Decodable {
        let location: String
        let hasDropoffRamp: Bool?
        let hasRails: Bool?
        let doorType: String?
        let isWideEnough: Bool?
        let reviewText: String?
        let photoUrls: [String]?

        enum CodingKeys: String, CodingKey {
            case location
            case hasDropoffRamp = "has_dropoff_ramp"
            case hasRails = "has_rails"
            case doorType = "door_type"
            case isWideEnough = "is_wide_enough"
            case reviewText = "review_text"
            case photoUrls = "photo_urls"
        }
    }

    struct DBPlaceReviewRow: Decodable {
        let id: UUID
        let createdAt: String
        let notes: String?
        let elevatorExists: Bool?
        let elevatorWheelchairAccessible: Bool?
        let elevatorBlockers: [String]?
        let elevatorReviewText: String?
        let elevatorPhotoUrls: [String]?
        let hasDisabledToilet: Bool?
        let toiletReviewText: String?
        let toiletPhotoUrls: [String]?
        let reviewEntrances: [DBReviewEntranceRow]?

        enum CodingKeys: String, CodingKey {
            case id
            case createdAt = "created_at"
            case notes
            case elevatorExists = "elevator_exists"
            case elevatorWheelchairAccessible = "elevator_wheelchair_accessible"
            case elevatorBlockers = "elevator_blockers"
            case elevatorReviewText = "elevator_review_text"
            case elevatorPhotoUrls = "elevator_photo_urls"
            case hasDisabledToilet = "has_disabled_toilet"
            case toiletReviewText = "toilet_review_text"
            case toiletPhotoUrls = "toilet_photo_urls"
            case reviewEntrances = "review_entrances"
        }
    }

    /// Loads flattened review rows + entrance children for one canonical place.
    ///
    /// Takes the place_id rather than a coordinate on purpose: this queries
    /// `reviews` directly, so unlike the Edge Functions it cannot resolve
    /// identity itself. The caller (PlaceReviewStore) passes the id enrich()
    /// resolved, which is the one the backend actually filed reviews under.
    func fetchPlaceReviews(placeId: String) async throws -> [PlaceFacilityReview] {
        let rows: [DBPlaceReviewRow] = try await client.from("reviews")
            .select("""
                id, created_at, notes,
                elevator_exists, elevator_wheelchair_accessible, elevator_blockers,
                elevator_review_text, elevator_photo_urls,
                has_disabled_toilet, toilet_review_text, toilet_photo_urls,
                review_entrances(location, has_dropoff_ramp, has_rails, door_type, is_wide_enough, review_text, photo_urls)
            """)
            .eq("place_id", value: placeId)
            .order("created_at", ascending: false)
            .execute()
            .value

        return Self.mapReviews(rows)
    }

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

    static func mapReviews(_ rows: [DBPlaceReviewRow]) -> [PlaceFacilityReview] {
        var results: [PlaceFacilityReview] = []
        for row in rows {
            let date = parseDate(row.createdAt)
            if let entrances = row.reviewEntrances {
                for entrance in entrances {
                    let body = entrance.reviewText?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? row.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
                        ?? ""
                    let hasFacilityData =
                        entrance.hasDropoffRamp != nil
                        || entrance.hasRails != nil
                        || entrance.doorType != nil
                        || entrance.isWideEnough != nil
                    guard !body.isEmpty || !(entrance.photoUrls ?? []).isEmpty || hasFacilityData else {
                        continue
                    }
                    results.append(PlaceFacilityReview(
                        id: UUID(),
                        reviewId: row.id,
                        kind: .entrance,
                        createdAt: date,
                        bodyText: body.isEmpty ? "Community review" : body,
                        providedTags: entranceTags(from: entrance),
                        photoURLs: entrance.photoUrls ?? []
                    ))
                }
            }
            if row.elevatorExists != nil || row.elevatorWheelchairAccessible != nil
                || !(row.elevatorReviewText ?? "").isEmpty
                || !(row.elevatorPhotoUrls ?? []).isEmpty {
                let body = row.elevatorReviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                results.append(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .elevator,
                    createdAt: date,
                    bodyText: body.isEmpty ? "Community review" : body,
                    providedTags: elevatorTags(from: row),
                    photoURLs: row.elevatorPhotoUrls ?? []
                ))
            }
            if row.hasDisabledToilet == false {
                results.append(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .toilet,
                    createdAt: date,
                    bodyText: row.toiletReviewText ?? "No accessible toilet reported",
                    providedTags: ["NOT AVAILABLE"],
                    photoURLs: row.toiletPhotoUrls ?? []
                ))
            } else if row.hasDisabledToilet == true
                        || !(row.toiletReviewText ?? "").isEmpty
                        || !(row.toiletPhotoUrls ?? []).isEmpty {
                let body = row.toiletReviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                results.append(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .toilet,
                    createdAt: date,
                    bodyText: body.isEmpty ? "Community review" : body,
                    providedTags: toiletTags(from: row),
                    photoURLs: row.toiletPhotoUrls ?? []
                ))
            }
        }
        return results
    }

    private static func parseDate(_ value: String) -> Date {
        isoFormatter.date(from: value) ?? isoFormatterFallback.date(from: value) ?? Date()
    }

    private static func entranceTags(from row: DBReviewEntranceRow) -> [String] {
        var tags: [String] = []
        if row.hasDropoffRamp == true { tags.append("RAMP") }
        if row.hasRails == true { tags.append("HANDRAIL") }
        if row.doorType == "automatic" { tags.append("AUTOMATIC DOORS") }
        if row.doorType == "manual" { tags.append("MANUAL DOORS") }
        if row.isWideEnough == true { tags.append("WIDE ENTRANCE") }
        return tags
    }

    private static func elevatorTags(from row: DBPlaceReviewRow) -> [String] {
        if row.elevatorExists == false { return ["NOT AVAILABLE"] }
        var tags: [String] = []
        if row.elevatorWheelchairAccessible == true { tags.append("WHEELCHAIR ACCESSIBLE") }
        if row.elevatorWheelchairAccessible == false { tags.append("LIMITED ACCESS") }
        if let blockers = row.elevatorBlockers {
            if blockers.contains("no_ramp") { tags.append("NO RAMP") }
            if blockers.contains("too_small") { tags.append("TOO SMALL") }
        }
        if tags.isEmpty, row.elevatorExists == true { tags.append("ELEVATOR") }
        return tags
    }

    private static func toiletTags(from row: DBPlaceReviewRow) -> [String] {
        if row.hasDisabledToilet == true { return ["ACCESSIBLE TOILET"] }
        return []
    }
}
