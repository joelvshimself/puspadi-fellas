import Foundation

@MainActor
final class SavedPlacesService: ObservableObject {
    static let shared = SavedPlacesService()

    enum SaveOutcome: Equatable {
        case saved
        case removed
        case needsSignIn
        case failed(String)
    }

    private struct SavedPlacesResponse: Decodable { let placeIds: [String] }

    @Published private(set) var savedPlaceIds: Set<String> = []
    private var mutationsInFlight: Set<String> = []
    private var stateVersion = 0
    private var fetchVersion = 0
    private let client = CloudflareAPIClient.shared
    private var authObserver: NSObjectProtocol?

    private init() {
        authObserver = NotificationCenter.default.addObserver(
            forName: .rollspotAuthStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.refreshForAuthChange() }
        }
    }

    func fetchSavedPlaceIds() async {
        fetchVersion += 1
        let thisFetch = fetchVersion
        let startingStateVersion = stateVersion
        guard AuthTokenStore.load() != nil else {
            savedPlaceIds = []
            return
        }
        do {
            let response: SavedPlacesResponse = try await client.get(
                ["v1", "saved-places"],
                authenticated: true
            )
            guard thisFetch == fetchVersion, startingStateVersion == stateVersion else { return }
            savedPlaceIds = Set(response.placeIds)
        } catch {
            print("[SavedPlacesService] Fetch failed: \(error)")
        }
    }

    func isSaved(placeId: String) -> Bool { savedPlaceIds.contains(placeId) }

    @discardableResult
    func toggleSave(placeId: String, place: Place? = nil) async -> SaveOutcome {
        guard AuthTokenStore.load() != nil else { return .needsSignIn }
        guard mutationsInFlight.insert(placeId).inserted else {
            return .failed("This place is already being updated.")
        }
        defer { mutationsInFlight.remove(placeId) }
        stateVersion += 1

        let removing = savedPlaceIds.contains(placeId)
        do {
            if removing {
                try await client.delete(["v1", "saved-places", placeId])
                savedPlaceIds.remove(placeId)
                SavedPlaceSnapshotStore.remove(placeId: placeId)
                return .removed
            }
            try await client.send(["v1", "saved-places", placeId], method: "PUT", authenticated: true)
            savedPlaceIds.insert(placeId)
            if let place { SavedPlaceSnapshotStore.save(place, placeId: placeId) }
            return .saved
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func refreshForAuthChange() async {
        stateVersion += 1
        fetchVersion += 1
        if AuthTokenStore.load() == nil {
            savedPlaceIds = []
        } else {
            await fetchSavedPlaceIds()
        }
    }
}
