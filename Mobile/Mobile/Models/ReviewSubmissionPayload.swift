import Foundation

/// Exact wire shape of `POST /functions/v1/submit-accessibility-review`, per
/// the backend teammate's contract. `ReviewDraft.buildSubmissionPayload()`
/// maps the wizard's local state onto this 1:1 — see ReviewService for the
/// live call site (photos are uploaded to Storage first; URLs land here).
///
/// Example payload the backend gave us:
/// ```json
/// {
///   "appleMapsId": "flatten-test-marina-bay",
///   "lat": 1.2834,
///   "lng": 103.8607,
///   "entrances": [
///     { "location": "lobby", "hasDropoffRamp": true, "hasRails": true,
///       "doorType": "automatic", "isWideEnough": true,
///       "review": { "text": "Main lobby drop-off is smooth", "photoUrls": [] } },
///     { "location": "basement", "hasDropoffRamp": false, "hasRails": null,
///       "doorType": "manual", "isWideEnough": false, "review": null }
///   ],
///   "elevator": { "exists": true, "wheelchairAccessible": false,
///                 "blockers": ["too_small"], "review": null },
///   "toilet": { "hasDisabledToilet": true,
///               "review": { "text": null, "photoUrls": [] } }
/// }
/// ```
struct ReviewSubmissionPayload: Encodable {
    let appleMapsId: String
    let lat: Double
    let lng: Double
    /// Lets the backend map (lat, lng, name) onto an existing place_id rather
    /// than minting one from the coordinate — see ReviewDraft.name.
    let name: String?
    let entrances: [EntranceReport]?
    let elevator: ElevatorReport?
    let toilet: ToiletReport?

    struct EntranceReport: Encodable {
        let location: String
        let hasDropoffRamp: Bool?
        let hasRails: Bool?
        let doorType: String?
        let isWideEnough: Bool?
        let review: Review?
    }

    struct ElevatorReport: Encodable {
        let exists: Bool?
        let wheelchairAccessible: Bool?
        let blockers: [String]
        let review: Review?
    }

    struct ToiletReport: Encodable {
        let hasDisabledToilet: Bool?
        let review: Review?
    }

    struct Review: Encodable {
        let text: String?
        let photoUrls: [String]
    }
}

/// Public Storage URLs produced by `ReviewService` before building the payload.
struct ReviewPhotoURLMap {
    var lobby: [String] = []
    var basement: [String] = []
    var elevator: [String] = []
    var toilet: [String] = []
}

extension ReviewNoteDraft {
    /// Empty text + empty URLs → nil review (matches contract:
    /// "review with text=null and photoUrls=[] = same as review:null").
    fileprivate func asReview(photoUrls: [String]) -> ReviewSubmissionPayload.Review? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty && photoUrls.isEmpty { return nil }
        return .init(text: trimmedText.isEmpty ? nil : trimmedText, photoUrls: photoUrls)
    }
}

extension EntranceDraft {
    fileprivate func asReport(photoUrls: [String]) -> ReviewSubmissionPayload.EntranceReport {
        .init(
            location: location.rawValue,
            hasDropoffRamp: hasDropoffRamp,
            hasRails: hasRails,
            doorType: doorType?.rawValue,
            isWideEnough: isWideEnough,
            review: review.asReview(photoUrls: photoUrls)
        )
    }
}

extension ReviewDraft {
    /// Builds the request body from wizard state plus Storage public URLs
    /// for each facility's note photos.
    func buildSubmissionPayload(photoUrls: ReviewPhotoURLMap) -> ReviewSubmissionPayload {
        let elevatorReport = ReviewSubmissionPayload.ElevatorReport(
            exists: elevator.exists,
            wheelchairAccessible: elevator.exists == true ? elevator.wheelchairAccessible : nil,
            // Contract: strip blockers unless wheelchairAccessible == false.
            blockers: elevator.wheelchairAccessible == false ? elevator.blockers.map(\.rawValue) : [],
            review: elevator.review.asReview(photoUrls: photoUrls.elevator)
        )
        let toiletReport = ReviewSubmissionPayload.ToiletReport(
            hasDisabledToilet: toilet.hasDisabledToilet,
            review: toilet.review.asReview(photoUrls: photoUrls.toilet)
        )
        return ReviewSubmissionPayload(
            appleMapsId: appleMapsId,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            name: name,
            entrances: [
                lobby.asReport(photoUrls: photoUrls.lobby),
                basement.asReport(photoUrls: photoUrls.basement),
            ],
            elevator: elevatorReport,
            toilet: toiletReport
        )
    }
}
