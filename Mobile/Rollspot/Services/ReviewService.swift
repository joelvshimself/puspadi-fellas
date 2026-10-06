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

    /// Loads community review photos for the Apple Place ID.
    func fetchReviewPhotos(placeId: String) async throws -> PlaceReviewPhotosResponse {
        try await client.get(["v1", "places", placeId, "review-photos"])
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

    /// Loads flattened review rows and display-safe reviewer identity.
    func fetchPlaceReviews(placeId: String) async throws -> [PlaceFacilityReview] {
        let response: PlaceReviewsResponse = try await client.get(
            ["v1", "places", placeId, "reviews"],
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
        // Keep rows that carry photos even when there is no prose or structured
        // tags — photo-only gallery uploads and entrance shots without chips
        // still belong in the Reviews list (Photos tab already shows them).
        return collapseRepeatVisits(
            results.filter {
                $0.review.hasBodyText
                    || !$0.review.providedTags.isEmpty
                    || !$0.review.photoURLs.isEmpty
            }
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
        let newestFirst = entries.sorted { PlaceFacilityReview.isNewerFirst($0.review, $1.review) }
        var seen = Set<String>()
        var kept: [PlaceFacilityReview] = []
        for entry in newestFirst {
            if let key = entry.key {
                guard seen.insert(key).inserted else { continue }
            }
            kept.append(entry.review)
        }
        return kept.sorted { PlaceFacilityReview.isNewerFirst($0, $1) }
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
