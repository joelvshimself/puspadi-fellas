import Foundation

/// Local persistence for in-progress contribute review flows.
enum UnfinishedReviewStore {
    struct Snapshot: Codable {
        let placeId: String
        let placeName: String
        let lat: Double
        let lng: Double
        let startingFacility: String?
        let screenIndex: Int
        let selectedFacilities: [String]
        let entranceLocation: String?
        let entranceTags: [String]
        let elevatorTags: [String]
        let toiletTags: [String]
        let lobbyNote: String
        let basementNote: String
        let elevatorNote: String
        let toiletNote: String
        let updatedAt: Date
    }

    private static let key = "unfinishedReviewSnapshots"

    static func save(
        place: Place,
        startingFacility: FacilityKind?,
        screenIndex: Int,
        selectedFacilities: Set<FacilityKind>,
        entranceLocation: EntranceLocation?,
        entranceTags: Set<ContributeTagOption>,
        elevatorTags: Set<ContributeTagOption>,
        toiletTags: Set<ContributeTagOption>,
        draft: ReviewDraft
    ) {
        let placeId = Place.canonicalPlaceId(from: place.coordinate)
        var all = loadAll()
        all[placeId] = Snapshot(
            placeId: placeId,
            placeName: place.name,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            startingFacility: startingFacility?.rawValue,
            screenIndex: screenIndex,
            selectedFacilities: selectedFacilities.map(\.rawValue),
            entranceLocation: entranceLocation?.rawValue,
            entranceTags: entranceTags.map(\.label),
            elevatorTags: elevatorTags.map(\.label),
            toiletTags: toiletTags.map(\.label),
            lobbyNote: draft.lobby.review.text,
            basementNote: draft.basement.review.text,
            elevatorNote: draft.elevator.review.text,
            toiletNote: draft.toilet.review.text,
            updatedAt: Date()
        )
        persist(all)
    }

    static func snapshot(for place: Place) -> Snapshot? {
        loadAll()[Place.canonicalPlaceId(from: place.coordinate)]
    }

    static func hasUnfinished(for place: Place) -> Bool {
        snapshot(for: place) != nil
    }

    static func clear(for place: Place) {
        var all = loadAll()
        all.removeValue(forKey: Place.canonicalPlaceId(from: place.coordinate))
        persist(all)
    }

    static func restoreTags(_ labels: [String], for kind: FacilityKind) -> Set<ContributeTagOption> {
        let catalog = ContributeReviewTags.tags(for: kind)
        return Set(labels.compactMap { label in catalog.first { $0.label == label } })
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
