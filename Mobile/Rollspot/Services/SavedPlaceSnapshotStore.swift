import MapKit

/// Keeps Apple Maps results only for the current process. Saved records in D1
/// contain just the Apple Place ID; current place data is resolved from MapKit.
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
        guard let identifier = MKMapItem.Identifier(rawValue: placeId) else { return nil }
        do {
            let item = try await MKMapItemRequest(mapItemIdentifier: identifier).mapItem
            guard let place = NearbyPlacesService.makePlace(from: item) else { return nil }
            places[placeId] = place
            return place
        } catch {
            print("[SavedPlaceSnapshotStore] Apple Maps lookup failed: \(error)")
            return nil
        }
    }
}
