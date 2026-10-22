import Foundation
import Shared

/// The shared `ContributeDrafts.waiting` for SwiftUI: the signed-in user's newest unfinished
/// contribution, shown by Home's "Continue Survey" banner and the Profile "ongoing review" row.
@MainActor
final class ContributeDraftsStore: ObservableObject {
    static let shared = ContributeDraftsStore()

    @Published private(set) var waiting: WaitingContribution?

    private init() {
        Task { [weak self] in
            for await value in RollspotServices.sdk.drafts.waiting {
                self?.waiting = value
            }
        }
    }

    /// Where to resume. A draft whose answers are gone (e.g. cleared app data) is dropped instead.
    func place(for contribution: WaitingContribution) -> Place? {
        if let place = UnfinishedReviewStore.place(forPlaceId: contribution.placeId) { return place }
        RollspotServices.sdk.drafts.forget(placeId: contribution.placeId)
        return nil
    }
}
