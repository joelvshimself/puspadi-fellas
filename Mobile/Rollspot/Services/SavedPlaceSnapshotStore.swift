import CoreLocation
import Foundation
import SwiftUI

/// Persists full Place snapshots for saved bookmarks (Supabase only stores place_id).
enum SavedPlaceSnapshotStore {
    private static let key = "savedPlaceSnapshots"

    struct Snapshot: Codable {
        let id: UUID
        let name: String
        let category: String
        let distance: String
        var address: String
        let lat: Double
        let lng: Double
    }

    static func save(_ place: Place, placeId: String) {
        var all = loadAll()
        all[placeId] = Snapshot(
            id: place.id,
            name: place.name,
            category: place.category,
            distance: place.distance,
            address: place.address,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        persist(all)
    }

    static func remove(placeId: String) {
        var all = loadAll()
        all.removeValue(forKey: placeId)
        persist(all)
    }

    static func place(for placeId: String) -> Place? {
        guard let snap = loadAll()[placeId] else { return nil }
        return Place(
            id: snap.id,
            name: snap.name,
            category: snap.category,
            distance: snap.distance,
            address: snap.address,
            ratingLabel: "",
            summary: "",
            description: "",
            coordinate: CLLocationCoordinate2D(latitude: snap.lat, longitude: snap.lng),
            accentColor: .accentColor,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            isLiveResult: true
        )
    }

    static func savedPlaces(from ids: Set<String>) -> [Place] {
        let all = loadAll()
        return ids.compactMap { all[$0].map { snap in
            Place(
                id: snap.id,
                name: snap.name,
                category: snap.category,
                distance: snap.distance,
                address: snap.address,
                ratingLabel: "",
                summary: "",
                description: "",
                coordinate: CLLocationCoordinate2D(latitude: snap.lat, longitude: snap.lng),
                accentColor: .accentColor,
                gallerySymbols: [],
                facilitySymbols: [],
                elevatorDetails: [],
                reviewsSummary: "",
                isLiveResult: true
            )
        }}
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func loadAll() -> [String: Snapshot] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: Snapshot].self, from: data)
        else { return [:] }
        return decoded
    }

    private static func persist(_ all: [String: Snapshot]) {
        if let data = try? JSONEncoder().encode(all) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
