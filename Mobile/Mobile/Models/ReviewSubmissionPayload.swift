import Foundation

/// Exact wire shape of `POST /functions/v1/submit-accessibility-review`, per
/// the backend teammate's contract. `ReviewDraft.buildSubmissionPayload()`
/// maps the wizard's local state onto this 1:1 — see ReviewService for the
/// (stubbed) call site.
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

extension ReviewNoteDraft {
    /// Empty text → nil, no photos picked → nil review entirely (matches
    /// contract: "review with text=null and photoUrls=[] = same as review:null").
    /// TODO(backend): photoImage never becomes a URL in this pass — real flow
    /// uploads to Storage first and puts the resulting URLs here.
    fileprivate var asReview: ReviewSubmissionPayload.Review? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty && photoImage == nil { return nil }
        return .init(text: trimmedText.isEmpty ? nil : trimmedText, photoUrls: [])
    }
}

extension EntranceDraft {
    fileprivate var asReport: ReviewSubmissionPayload.EntranceReport {
        .init(
            location: location.rawValue,
            hasDropoffRamp: hasDropoffRamp,
            hasRails: hasRails,
            doorType: doorType?.rawValue,
            isWideEnough: isWideEnough,
            review: review.asReview
        )
    }
}

extension ReviewDraft {
    /// Builds the real request body from current wizard state — sent by
    /// ReviewService.submit to the live `submit-accessibility-review` Edge Function.
    func buildSubmissionPayload() -> ReviewSubmissionPayload {
        let elevatorReport = ReviewSubmissionPayload.ElevatorReport(
            exists: elevator.exists,
            wheelchairAccessible: elevator.exists == true ? elevator.wheelchairAccessible : nil,
            // Contract: strip blockers unless wheelchairAccessible == false.
            blockers: elevator.wheelchairAccessible == false ? elevator.blockers.map(\.rawValue) : [],
            review: elevator.review.asReview
        )
        let toiletReport = ReviewSubmissionPayload.ToiletReport(
            hasDisabledToilet: toilet.hasDisabledToilet,
            review: toilet.review.asReview
        )
        return ReviewSubmissionPayload(
            appleMapsId: appleMapsId,
            lat: coordinate.latitude,
            lng: coordinate.longitude,
            entrances: [lobby.asReport, basement.asReport],
            elevator: elevatorReport,
            toilet: toiletReport
        )
    }
}
