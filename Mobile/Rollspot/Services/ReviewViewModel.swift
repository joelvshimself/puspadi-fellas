import Foundation
import Shared

/// Thin Swift wrapper over the shared [ReviewModel] for SwiftUI observation.
@MainActor
final class ReviewViewModel: ObservableObject {
    @Published private(set) var state: ReviewState

    private let model = RollspotServices.sdk.reviews

    init() {
        state = model.state.value
    }

    func submit(submission: ReviewSubmission, photos: [PendingReviewPhoto]) async throws -> ReviewSubmitted {
        defer { syncState() }
        return try await model.submit(submission: submission, photos: photos)
    }

    func load(reviewId: String) async throws -> ReviewById {
        defer { syncState() }
        return try await model.load(reviewId: reviewId)
    }

    func loadMine() async throws -> MyReviews {
        defer { syncState() }
        return try await model.loadMine()
    }

    func delete(reviewId: String) async throws {
        defer { syncState() }
        try await model.delete(reviewId: reviewId)
    }

    func clearOutcome() {
        model.clearOutcome()
        syncState()
    }

    private func syncState() {
        state = model.state.value
    }
}
