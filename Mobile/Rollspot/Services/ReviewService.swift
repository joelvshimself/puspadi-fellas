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

    private struct EmptyRequestBody: Encodable {}

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
            return ReviewPhotoDraft(
                image: image,
                jpegData: data,
                caption: photo.caption ?? ""
            )
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
            (urlMap.lobby, urlMap.lobbyCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                appleMapsId: draft.appleMapsId,
                facility: "lobby"
            )
        case .elevator:
            draft.elevator.review.photos = jpegPhotos
            (urlMap.elevator, urlMap.elevatorCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                appleMapsId: draft.appleMapsId,
                facility: "elevator"
            )
        case .toilet:
            draft.toilet.review.photos = jpegPhotos
            (urlMap.toilet, urlMap.toiletCaptions) = try await uploadPhotosWithCaptions(
                jpegPhotos,
                appleMapsId: draft.appleMapsId,
                facility: "toilet"
            )
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
        (map.lobby, map.lobbyCaptions) = try await uploadPhotosWithCaptions(
            draft.lobby.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "lobby"
        )
        (map.basement, map.basementCaptions) = try await uploadPhotosWithCaptions(
            draft.basement.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "basement"
        )
        (map.elevator, map.elevatorCaptions) = try await uploadPhotosWithCaptions(
            draft.elevator.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "elevator"
        )
        (map.toilet, map.toiletCaptions) = try await uploadPhotosWithCaptions(
            draft.toilet.review.photos,
            appleMapsId: draft.appleMapsId,
            facility: "toilet"
        )
        return map
    }

    private func uploadPhotosWithCaptions(
        _ photos: [ReviewPhotoDraft],
        appleMapsId: String,
        facility: String
    ) async throws -> ([String], [String]) {
        let urls = try await uploadPhotos(photos, appleMapsId: appleMapsId, facility: facility)
        let captions = photos.map {
            $0.caption.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return (urls, captions)
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

    /// Fetches reviews authored by the signed-in user via the `my-reviews` Edge Function.
    func fetchMyReviews() async throws -> MyReviewsResponse {
        try await NetworkRetry.run {
            try await client.functions.invoke(
                "my-reviews",
                options: FunctionInvokeOptions(body: EmptyRequestBody()),
                decoder: decoder
            )
        }
    }

    /// Deletes the signed-in user's review row (cascades entrance children via FK).
    func deleteMyReview(id: UUID) async throws {
        try await client.from("reviews")
            .delete()
            .eq("id", value: id)
            .execute()
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
        let photoCaptions: [String]?

        enum CodingKeys: String, CodingKey {
            case location
            case hasDropoffRamp = "has_dropoff_ramp"
            case hasRails = "has_rails"
            case doorType = "door_type"
            case isWideEnough = "is_wide_enough"
            case reviewText = "review_text"
            case photoUrls = "photo_urls"
            case photoCaptions = "photo_captions"
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
        let elevatorPhotoCaptions: [String]?
        let hasDisabledToilet: Bool?
        let toiletReviewText: String?
        let toiletPhotoUrls: [String]?
        let toiletPhotoCaptions: [String]?
        let reviewEntrances: [DBReviewEntranceRow]?
        /// Joined server-side by place-reviews; nil for legacy anonymous rows.
        let reviewerName: String?
        let reviewerRole: String?
        let reviewerAvatarUrl: String?
        /// Both default when absent, so a client running against a backend
        /// that predates the pseudonym/provenance migration still decodes.
        let reviewerIsPseudonym: Bool?
        let provenance: String?
        let sourceUrl: String?

        enum CodingKeys: String, CodingKey {
            case id
            case createdAt = "created_at"
            case notes
            case elevatorExists = "elevator_exists"
            case elevatorWheelchairAccessible = "elevator_wheelchair_accessible"
            case elevatorBlockers = "elevator_blockers"
            case elevatorReviewText = "elevator_review_text"
            case elevatorPhotoUrls = "elevator_photo_urls"
            case elevatorPhotoCaptions = "elevator_photo_captions"
            case hasDisabledToilet = "has_disabled_toilet"
            case toiletReviewText = "toilet_review_text"
            case toiletPhotoUrls = "toilet_photo_urls"
            case toiletPhotoCaptions = "toilet_photo_captions"
            case reviewEntrances = "review_entrances"
            case reviewerName = "reviewer_name"
            case reviewerRole = "reviewer_role"
            case reviewerAvatarUrl = "reviewer_avatar_url"
            case reviewerIsPseudonym = "reviewer_is_pseudonym"
            case provenance
            case sourceUrl = "source_url"
        }
    }

    private struct PlaceReviewsResponse: Decodable {
        let status: String
        let reviews: [DBPlaceReviewRow]
    }

    private struct PlaceReviewsRequestBody: Encodable {
        let placeId: String
    }

    /// Loads flattened review rows + entrance children + reviewer identity for
    /// one canonical place, via the `place-reviews` Edge Function.
    ///
    /// An Edge Function rather than a direct table query, because reviewer
    /// names live in `profiles` and RLS only lets a user read their own row —
    /// the service role joins them server-side. Takes the place_id enrich()
    /// resolved, which is the one the backend actually filed reviews under.
    func fetchPlaceReviews(placeId: String) async throws -> [PlaceFacilityReview] {
        // Rows come back snake_case and DBPlaceReviewRow's CodingKeys already
        // spell that out — the class-level convertFromSnakeCase decoder would
        // fight them, so this call uses a plain decoder.
        let response: PlaceReviewsResponse = try await client.functions.invoke(
            "place-reviews",
            options: FunctionInvokeOptions(body: PlaceReviewsRequestBody(placeId: placeId)),
            decoder: JSONDecoder()
        )
        return Self.mapReviews(response.reviews)
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

    /// Fans each stored review out into one row per facility it says something
    /// about.
    ///
    /// `bodyText` is whatever the contributor actually typed, and is EMPTY when
    /// they typed nothing — which is the common case, since the contribute flow
    /// is mostly structured questions and the free-text box is optional. It
    /// used to be filled with the literal string "Community review" instead, so
    /// a place's overview showed three identical "Community review" rows under
    /// "Notes from reviews" and the review cards all carried the same fake
    /// sentence. A note nobody wrote is not a note; the structured answers are
    /// carried by `providedTags`, and callers that want prose check for it.
    static func mapReviews(_ rows: [DBPlaceReviewRow]) -> [PlaceFacilityReview] {
        var results: [(key: String?, review: PlaceFacilityReview)] = []
        for row in rows {
            let date = parseDate(row.createdAt)
            /// Same reviewer on every facility row this review fans out into.
            func withReviewer(_ review: PlaceFacilityReview) -> PlaceFacilityReview {
                var copy = review
                copy.reviewerName = row.reviewerName
                copy.reviewerRole = row.reviewerRole
                copy.reviewerIsPseudonym = row.reviewerIsPseudonym ?? false
                copy.provenance = ReviewProvenance(rawValueOrCommunity: row.provenance)
                copy.sourceURL = row.sourceUrl.flatMap(URL.init(string:))
                copy.reviewerAvatarURL = row.reviewerAvatarUrl.flatMap(URL.init(string:))
                return copy
            }
            if let entrances = row.reviewEntrances {
                for entrance in entrances {
                    // The entrance's OWN text only — never the review-level
                    // `notes` aggregate: that column is every facility's text
                    // joined with internal "[entrance:basement]" prefixes, and
                    // falling back to it rendered a phantom duplicate row for
                    // the entrance the user did NOT review.
                    let body = entrance.reviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let hasFacilityData =
                        entrance.hasDropoffRamp != nil
                        || entrance.hasRails != nil
                        || entrance.doorType != nil
                        || entrance.isWideEnough != nil
                    guard !body.isEmpty || !(entrance.photoUrls ?? []).isEmpty || hasFacilityData else {
                        continue
                    }
                    results.append((
                        // Per entrance, not per review: one review legitimately
                        // covers both the lobby and the basement, and those are
                        // two different doors.
                        dedupeKey(row, "entrance-\(entrance.location)"),
                        withReviewer(PlaceFacilityReview(
                            id: UUID(),
                            reviewId: row.id,
                            kind: .entrance,
                            createdAt: date,
                            bodyText: body,
                            providedTags: entranceTags(from: entrance),
                            photoURLs: entrance.photoUrls ?? [],
                            photoCaptions: entrance.photoCaptions ?? []
                        ))
                    ))
                }
            }
            if row.elevatorExists != nil || row.elevatorWheelchairAccessible != nil
                || !(row.elevatorReviewText ?? "").isEmpty
                || !(row.elevatorPhotoUrls ?? []).isEmpty {
                let body = row.elevatorReviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                results.append((dedupeKey(row, "elevator"), withReviewer(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .elevator,
                    createdAt: date,
                    bodyText: body,
                    providedTags: elevatorTags(from: row),
                    photoURLs: row.elevatorPhotoUrls ?? [],
                    photoCaptions: row.elevatorPhotoCaptions ?? []
                ))))
            }
            if row.hasDisabledToilet == false {
                results.append((dedupeKey(row, "toilet"), withReviewer(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .toilet,
                    createdAt: date,
                    bodyText: (row.toiletReviewText ?? "").trimmingCharacters(in: .whitespacesAndNewlines),
                    providedTags: ["NOT AVAILABLE"],
                    photoURLs: row.toiletPhotoUrls ?? [],
                    photoCaptions: row.toiletPhotoCaptions ?? []
                ))))
            } else if row.hasDisabledToilet == true
                        || !(row.toiletReviewText ?? "").isEmpty
                        || !(row.toiletPhotoUrls ?? []).isEmpty {
                let body = row.toiletReviewText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                results.append((dedupeKey(row, "toilet"), withReviewer(PlaceFacilityReview(
                    id: UUID(),
                    reviewId: row.id,
                    kind: .toilet,
                    createdAt: date,
                    bodyText: body,
                    providedTags: toiletTags(from: row),
                    photoURLs: row.toiletPhotoUrls ?? [],
                    photoCaptions: row.toiletPhotoCaptions ?? []
                ))))
            }
        }
        // A row carrying nothing but an uploaded image is not a review —
        // there is no verdict in it to read. Photos on a review that DOES say
        // something are untouched.
        return collapseRepeatVisits(
            results.filter { $0.review.hasBodyText || !$0.review.providedTags.isEmpty }
        )
    }

    /// Identifies "this person's verdict on this specific facility". Nil when
    /// the row carries no reviewer, which is every pre-auth row — those cannot
    /// be attributed to anyone, so they are never collapsed together.
    private static func dedupeKey(_ row: DBPlaceReviewRow, _ facility: String) -> String? {
        guard let reviewer = row.reviewerName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !reviewer.isEmpty else { return nil }
        return "\(reviewer)|\(facility)"
    }

    /// One verdict per person per facility, keeping their most recent.
    ///
    /// Somebody who reviews the same mall five times is not five reviewers,
    /// and the list was rendering them as five near-identical cards under the
    /// same name. It also disagreed with the backend: review_to_signals()
    /// deletes a place's earlier review signals on every new one, so the GRADE
    /// has always been "newest review wins" while the list still showed the
    /// superseded ones as if they were corroborating evidence. accessibility_
    /// signals goes further and holds a unique (place, feature, source, user)
    /// so nobody can stack weight by repeating themselves; this is the same
    /// rule applied to what a reader sees.
    ///
    /// Collapsing is per FACILITY, not per review, so a later visit that only
    /// covers the toilet does not erase what the same person said about the
    /// entrance months earlier.
    private static func collapseRepeatVisits(
        _ entries: [(key: String?, review: PlaceFacilityReview)]
    ) -> [PlaceFacilityReview] {
        let newestFirst = entries.sorted { $0.review.createdAt > $1.review.createdAt }
        var seen = Set<String>()
        var kept: [PlaceFacilityReview] = []
        for entry in newestFirst {
            if let key = entry.key {
                guard seen.insert(key).inserted else { continue }
            }
            kept.append(entry.review)
        }
        return kept
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
