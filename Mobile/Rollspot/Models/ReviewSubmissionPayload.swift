import Foundation

/// Wire shape of `POST /v1/reviews`. `ReviewDraft.buildSubmissionPayload()`
/// maps the wizard state onto it after photos have been uploaded to R2.
///
/// Example payload the backend gave us:
/// ```json
/// {
///   "placeId": "<Rollspot place ID>",
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
    let submissionId: UUID
    let placeId: String
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
        let photoCaptions: [String]
    }
}

/// Public R2 URLs produced by `ReviewService` before building the payload.
struct ReviewPhotoURLMap {
    var lobby: [String] = []
    var lobbyCaptions: [String] = []
    var basement: [String] = []
    var basementCaptions: [String] = []
    var elevator: [String] = []
    var elevatorCaptions: [String] = []
    var toilet: [String] = []
    var toiletCaptions: [String] = []
}

extension ReviewNoteDraft {
    /// Empty text + empty URLs → nil review (matches contract:
    /// "review with text=null and photoUrls=[] = same as review:null").
    fileprivate func asReview(
        photoUrls: [String],
        photoCaptions: [String]
    ) -> ReviewSubmissionPayload.Review? {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.isEmpty && photoUrls.isEmpty { return nil }
        return .init(
            text: trimmedText.isEmpty ? nil : trimmedText,
            photoUrls: photoUrls,
            photoCaptions: photoCaptions
        )
    }
}

extension EntranceDraft {
    fileprivate func asReport(photoUrls: [String], photoCaptions: [String]) -> ReviewSubmissionPayload.EntranceReport {
        .init(
            location: location.rawValue,
            hasDropoffRamp: hasDropoffRamp,
            hasRails: hasRails,
            doorType: doorType?.rawValue,
            isWideEnough: isWideEnough,
            review: review.asReview(photoUrls: photoUrls, photoCaptions: photoCaptions)
        )
    }
}

extension ReviewDraft {
    /// Builds the request body from wizard state plus R2 public URLs
    /// for each facility's note photos.
    func buildSubmissionPayload(photoUrls: ReviewPhotoURLMap) -> ReviewSubmissionPayload {
        let elevatorReport = ReviewSubmissionPayload.ElevatorReport(
            exists: elevator.exists,
            wheelchairAccessible: elevator.exists == true ? elevator.wheelchairAccessible : nil,
            // Contract: strip blockers unless wheelchairAccessible == false.
            blockers: elevator.wheelchairAccessible == false ? elevator.blockers.map(\.rawValue) : [],
            review: elevator.review.asReview(
                photoUrls: photoUrls.elevator,
                photoCaptions: photoUrls.elevatorCaptions
            )
        )
        let toiletReport = ReviewSubmissionPayload.ToiletReport(
            hasDisabledToilet: toilet.hasDisabledToilet,
            review: toilet.review.asReview(
                photoUrls: photoUrls.toilet,
                photoCaptions: photoUrls.toiletCaptions
            )
        )
        // Only entrances the user actually answered. Sending both
        // unconditionally wrote an all-null row for the untouched one, which
        // then surfaced as a phantom review in Place Details.
        func hasContent(_ report: ReviewSubmissionPayload.EntranceReport) -> Bool {
            if report.hasDropoffRamp != nil { return true }
            if report.hasRails != nil { return true }
            if report.doorType != nil { return true }
            if report.isWideEnough != nil { return true }
            return report.review != nil
        }
        let lobbyReport = lobby.asReport(
            photoUrls: photoUrls.lobby,
            photoCaptions: photoUrls.lobbyCaptions
        )
        let basementReport = basement.asReport(
            photoUrls: photoUrls.basement,
            photoCaptions: photoUrls.basementCaptions
        )
        let entranceReports = [lobbyReport, basementReport].filter(hasContent)

        return ReviewSubmissionPayload(
            submissionId: submissionId,
            placeId: placeId,
            entrances: entranceReports.isEmpty ? nil : entranceReports,
            elevator: elevatorReport,
            toilet: toiletReport
        )
    }
}
