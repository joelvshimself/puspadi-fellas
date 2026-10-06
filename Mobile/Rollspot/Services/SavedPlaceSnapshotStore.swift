import MapKit

/// In-memory cache of saved places for this process; anything missing is
/// fetched from the place directory by ID.
@MainActor
enum SavedPlaceSnapshotStore {
    private static var places: [String: Place] = [:]

    static func save(_ place: Place, placeId: String) {
        places[placeId] = place
    }

    static func remove(placeId: String) {
        places.removeValue(forKey: placeId)
    }

    static func place(for placeId: String) -> Place? {
        places[placeId]
    }

    static func savedPlaces(from ids: Set<String>) -> [Place] {
        ids.compactMap { places[$0] }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    static func resolve(placeId: String) async -> Place? {
        if let place = places[placeId] { return place }
        guard let place = await NearbyPlacesService.place(key: placeId) else { return nil }
        places[placeId] = place
        return place
    }
}
