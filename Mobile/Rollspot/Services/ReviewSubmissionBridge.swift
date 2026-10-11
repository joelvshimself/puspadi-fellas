import Foundation
import Shared

extension ReviewSubmissionPayload {
    func asSharedSubmission() -> ReviewSubmission {
        ReviewSubmission(
            submissionId: submissionId.uuidString,
            placeId: placeId,
            entrances: entrances?.map { $0.asSharedEntrance() },
            elevator: elevator?.asSharedElevator(),
            toilet: toilet?.asSharedToilet()
        )
    }
}

private extension ReviewSubmissionPayload.EntranceReport {
    func asSharedEntrance() -> EntranceReport {
        EntranceReport(
            location: location,
            hasDropoffRamp: hasDropoffRamp,
            hasRails: hasRails,
            doorType: doorType,
            isWideEnough: isWideEnough,
            review: review?.asSharedNote()
        )
    }
}

private extension ReviewSubmissionPayload.ElevatorReport {
    func asSharedElevator() -> ElevatorReport {
        ElevatorReport(
            exists: exists,
            wheelchairAccessible: wheelchairAccessible,
            blockers: blockers,
            review: review?.asSharedNote()
        )
    }
}

private extension ReviewSubmissionPayload.ToiletReport {
    func asSharedToilet() -> ToiletReport {
        ToiletReport(
            hasDisabledToilet: hasDisabledToilet,
            review: review?.asSharedNote()
        )
    }
}

private extension ReviewSubmissionPayload.Review {
    func asSharedNote() -> ReviewNote {
        ReviewNote(text: text, photoUrls: photoUrls, photoCaptions: photoCaptions)
    }
}

extension ReviewDraft {
    func pendingReviewPhotos() -> [PendingReviewPhoto] {
        func map(_ photos: [ReviewPhotoDraft], slot: ReviewPhotoSlot) -> [PendingReviewPhoto] {
            photos.map { photo in
                PendingReviewPhoto(
                    slot: slot,
                    fileId: photo.id.uuidString,
                    jpeg: photo.jpegData.asKotlinByteArray(),
                    caption: photo.caption
                )
            }
        }
        return map(lobby.review.photos, slot: .lobby)
            + map(basement.review.photos, slot: .basement)
            + map(elevator.review.photos, slot: .elevator)
            + map(toilet.review.photos, slot: .toilet)
    }
}

extension ReviewSubmitted {
    func asSubmitResponse() -> ReviewService.SubmitResponse {
        ReviewService.SubmitResponse(
            status: "ok",
            reviewId: reviewId,
            placeId: placeId,
            grade: grade.map { AccessibilityFeatureGrade(feature: $0.feature, bestValue: $0.bestValue, confidence: $0.confidence) }
        )
    }
}

extension MyReviews {
    func asMyReviewsResponse() -> ReviewService.MyReviewsResponse {
        ReviewService.MyReviewsResponse(
            status: "ok",
            userName: userName,
            userRole: userRole,
            profileImageUrl: profileImageUrl,
            reviews: reviews.compactMap { row in
                guard let id = UUID(uuidString: row.id) else { return nil }
                return ReviewService.MyReviewItem(
                    id: id,
                    placeId: row.placeId,
                    placeName: row.placeName,
                    createdAt: row.createdAt,
                    reviewText: row.reviewText,
                    providedFeatures: row.providedFeatures,
                    photoUrls: row.photoUrls,
                    photoCaptions: row.photoCaptions
                )
            }
        )
    }
}
