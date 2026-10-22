import Foundation
import Shared

/// SwiftUI face of the shared `SavedPlacesModel`. Optimistic saving, rollback, the
/// one-request-per-place guard and clearing on sign-out all happen in shared code.
@MainActor
final class SavedPlacesService: ObservableObject {
    static let shared = SavedPlacesService()

    enum SaveOutcome: Equatable {
        case saved
        case removed
        case needsSignIn
        case failed(String)
    }

    @Published private(set) var savedPlaceIds: Set<String> = []
    /// Saved places A–Z, with the data the directory returned.
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var hasLoaded = false

    private var model: SavedPlacesModel { RollspotServices.sdk.saved }

    private init() {
        Task { [weak self] in
            guard let states = self?.model.state else { return }
            for await state in states {
                self?.apply(state)
            }
        }
    }

    func fetchSavedPlaceIds() async {
        try? await model.load()
    }

    func isSaved(placeId: String) -> Bool { savedPlaceIds.contains(placeId) }

    @discardableResult
    func toggleSave(placeId: String, place: Place? = nil) async -> SaveOutcome {
        // The shared model needs the directory row; saved places already have it.
        let shared: Shared.Place
        if let known = model.state.value.places.first(where: { $0.id == placeId }) {
            shared = known
        } else if RollspotServices.sdk.auth.isSignedIn {
            do {
                shared = try await RollspotServices.sdk.places.place(key: placeId)
            } catch {
                return .failed(error.localizedDescription)
            }
        } else {
            return .needsSignIn
        }
        // Only throws if cancelled; the model reports real failures as an outcome.
        guard let outcome = try? await model.toggle(place: shared) else { return .failed("Cancelled") }
        switch onEnum(of: outcome) {
        case .saved: return .saved
        case .removed: return .removed
        case .needsSignIn: return .needsSignIn
        case .failed(let failure): return .failed(failure.message)
        }
    }

    private func apply(_ state: SavedPlacesState) {
        savedPlaceIds = state.placeIds
        savedPlaces = state.places.map { NearbyPlacesService.makePlace(from: $0, distanceFrom: nil) }
        hasLoaded = state.hasLoaded
    }
}
