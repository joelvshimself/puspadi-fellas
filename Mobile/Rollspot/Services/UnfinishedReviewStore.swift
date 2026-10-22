import CoreLocation
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
        let entranceLocations: [String]
        let lobbyEntranceTags: [String]
        let basementEntranceTags: [String]
        let elevatorTags: [String]
        let toiletTags: [String]
        let lobbyNote: String
        let basementNote: String
        let elevatorNote: String
        let toiletNote: String
        let updatedAt: Date
        let completedCategories: [String]
        let inProgressCategories: [String]
        let categoryNotes: [String: String]
        /// The section open when the app left (resume lands back inside it), and its answers.
        var activeCategory: String? = nil
        var seatingAnswer: String? = nil
        var parkingAnswer: String? = nil
        var pathwayNotices: [String] = []
        var elevatorAnswers: [String: String] = [:]
        var toiletAnswers: [String: String] = [:]

        init(
            placeId: String,
            placeName: String,
            lat: Double,
            lng: Double,
            startingFacility: String?,
            screenIndex: Int,
            selectedFacilities: [String],
            entranceLocations: [String],
            lobbyEntranceTags: [String],
            basementEntranceTags: [String],
            elevatorTags: [String],
            toiletTags: [String],
            lobbyNote: String,
            basementNote: String,
            elevatorNote: String,
            toiletNote: String,
            updatedAt: Date,
            completedCategories: [String] = [],
            inProgressCategories: [String] = [],
            categoryNotes: [String: String] = [:]
        ) {
            self.placeId = placeId
            self.placeName = placeName
            self.lat = lat
            self.lng = lng
            self.startingFacility = startingFacility
            self.screenIndex = screenIndex
            self.selectedFacilities = selectedFacilities
            self.entranceLocations = entranceLocations
            self.lobbyEntranceTags = lobbyEntranceTags
            self.basementEntranceTags = basementEntranceTags
            self.elevatorTags = elevatorTags
            self.toiletTags = toiletTags
            self.lobbyNote = lobbyNote
            self.basementNote = basementNote
            self.elevatorNote = elevatorNote
            self.toiletNote = toiletNote
            self.updatedAt = updatedAt
            self.completedCategories = completedCategories
            self.inProgressCategories = inProgressCategories
            self.categoryNotes = categoryNotes
        }

        private enum CodingKeys: String, CodingKey {
            case placeId, placeName, lat, lng, startingFacility, screenIndex, selectedFacilities
            case entranceLocations, lobbyEntranceTags, basementEntranceTags, elevatorTags, toiletTags
            case lobbyNote, basementNote, elevatorNote, toiletNote, updatedAt
            case completedCategories, inProgressCategories, categoryNotes
            case activeCategory, seatingAnswer, parkingAnswer, pathwayNotices, elevatorAnswers, toiletAnswers
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            placeId = try c.decode(String.self, forKey: .placeId)
            placeName = try c.decode(String.self, forKey: .placeName)
            lat = try c.decode(Double.self, forKey: .lat)
            lng = try c.decode(Double.self, forKey: .lng)
            startingFacility = try c.decodeIfPresent(String.self, forKey: .startingFacility)
            screenIndex = try c.decode(Int.self, forKey: .screenIndex)
            selectedFacilities = try c.decode([String].self, forKey: .selectedFacilities)
            entranceLocations = try c.decode([String].self, forKey: .entranceLocations)
            lobbyEntranceTags = try c.decode([String].self, forKey: .lobbyEntranceTags)
            basementEntranceTags = try c.decode([String].self, forKey: .basementEntranceTags)
            elevatorTags = try c.decode([String].self, forKey: .elevatorTags)
            toiletTags = try c.decode([String].self, forKey: .toiletTags)
            lobbyNote = try c.decode(String.self, forKey: .lobbyNote)
            basementNote = try c.decode(String.self, forKey: .basementNote)
            elevatorNote = try c.decode(String.self, forKey: .elevatorNote)
            toiletNote = try c.decode(String.self, forKey: .toiletNote)
            updatedAt = try c.decode(Date.self, forKey: .updatedAt)
            completedCategories = try c.decodeIfPresent([String].self, forKey: .completedCategories) ?? []
            inProgressCategories = try c.decodeIfPresent([String].self, forKey: .inProgressCategories) ?? []
            categoryNotes = try c.decodeIfPresent([String: String].self, forKey: .categoryNotes) ?? [:]
            activeCategory = try c.decodeIfPresent(String.self, forKey: .activeCategory)
            seatingAnswer = try c.decodeIfPresent(String.self, forKey: .seatingAnswer)
            parkingAnswer = try c.decodeIfPresent(String.self, forKey: .parkingAnswer)
            pathwayNotices = try c.decodeIfPresent([String].self, forKey: .pathwayNotices) ?? []
            elevatorAnswers = try c.decodeIfPresent([String: String].self, forKey: .elevatorAnswers) ?? [:]
            toiletAnswers = try c.decodeIfPresent([String: String].self, forKey: .toiletAnswers) ?? [:]
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(placeId, forKey: .placeId)
            try c.encode(placeName, forKey: .placeName)
            try c.encode(lat, forKey: .lat)
            try c.encode(lng, forKey: .lng)
            try c.encodeIfPresent(startingFacility, forKey: .startingFacility)
            try c.encode(screenIndex, forKey: .screenIndex)
            try c.encode(selectedFacilities, forKey: .selectedFacilities)
            try c.encode(entranceLocations, forKey: .entranceLocations)
            try c.encode(lobbyEntranceTags, forKey: .lobbyEntranceTags)
            try c.encode(basementEntranceTags, forKey: .basementEntranceTags)
            try c.encode(elevatorTags, forKey: .elevatorTags)
            try c.encode(toiletTags, forKey: .toiletTags)
            try c.encode(lobbyNote, forKey: .lobbyNote)
            try c.encode(basementNote, forKey: .basementNote)
            try c.encode(elevatorNote, forKey: .elevatorNote)
            try c.encode(toiletNote, forKey: .toiletNote)
            try c.encode(updatedAt, forKey: .updatedAt)
            try c.encode(completedCategories, forKey: .completedCategories)
            try c.encode(inProgressCategories, forKey: .inProgressCategories)
            try c.encode(categoryNotes, forKey: .categoryNotes)
            try c.encodeIfPresent(activeCategory, forKey: .activeCategory)
            try c.encodeIfPresent(seatingAnswer, forKey: .seatingAnswer)
            try c.encodeIfPresent(parkingAnswer, forKey: .parkingAnswer)
            try c.encode(pathwayNotices, forKey: .pathwayNotices)
            try c.encode(elevatorAnswers, forKey: .elevatorAnswers)
            try c.encode(toiletAnswers, forKey: .toiletAnswers)
        }
    }

    /// The open section and its single-choice answers.
    struct SectionAnswers {
        var activeCategory: String? = nil
        var seatingAnswer: String? = nil
        var parkingAnswer: String? = nil
        var pathwayNotices: [String] = []
        var elevatorAnswers: [String: String] = [:]
        var toiletAnswers: [String: String] = [:]
    }

    private static let key = "unfinishedReviewSnapshots"

    static func save(
        place: Place,
        startingFacility: FacilityKind?,
        screenIndex: Int,
        selectedFacilities: Set<FacilityKind>,
        entranceLocations: Set<EntranceLocation>,
        lobbyEntranceTags: Set<ContributeTagOption>,
        basementEntranceTags: Set<ContributeTagOption>,
        elevatorTags: Set<ContributeTagOption>,
        toiletTags: Set<ContributeTagOption>,
        draft: ReviewDraft,
        completedCategories: [String] = [],
        inProgressCategories: [String] = [],
        categoryNotes: [String: String] = [:],
        section: SectionAnswers = SectionAnswers()
    ) {
        let placeId = place.reviewPlaceId
        var all = loadAll()
        all[placeId] = Snapshot(
            placeId: placeId,
            placeName: place.name,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            startingFacility: startingFacility?.rawValue,
            screenIndex: screenIndex,
            selectedFacilities: selectedFacilities.map(\.rawValue),
            entranceLocations: entranceLocations.map(\.rawValue),
            lobbyEntranceTags: lobbyEntranceTags.map(\.label),
            basementEntranceTags: basementEntranceTags.map(\.label),
            elevatorTags: elevatorTags.map(\.label),
            toiletTags: toiletTags.map(\.label),
            lobbyNote: draft.lobby.review.text,
            basementNote: draft.basement.review.text,
            elevatorNote: draft.elevator.review.text,
            toiletNote: draft.toilet.review.text,
            updatedAt: Date(),
            completedCategories: completedCategories,
            inProgressCategories: inProgressCategories,
            categoryNotes: categoryNotes
        )
        all[placeId]?.activeCategory = section.activeCategory
        all[placeId]?.seatingAnswer = section.seatingAnswer
        all[placeId]?.parkingAnswer = section.parkingAnswer
        all[placeId]?.pathwayNotices = section.pathwayNotices
        all[placeId]?.elevatorAnswers = section.elevatorAnswers
        all[placeId]?.toiletAnswers = section.toiletAnswers
        persist(all)
        // The Home "Continue Survey" banner reads the shared list.
        RollspotServices.sdk.drafts.remember(placeId: placeId, placeName: place.name)
    }

    static func snapshot(for place: Place) -> Snapshot? {
        loadAll()[place.reviewPlaceId]
    }

    static func hasUnfinished(for place: Place) -> Bool {
        snapshot(for: place) != nil
    }

    static func clear(for place: Place) {
        clear(placeId: place.reviewPlaceId)
    }

    static func clear(placeId: String) {
        var all = loadAll()
        all.removeValue(forKey: placeId)
        persist(all)
        RollspotServices.sdk.drafts.forget(placeId: placeId)
    }

    /// The place to resume a waiting contribution at, rebuilt from its snapshot.
    static func place(forPlaceId placeId: String) -> Place? {
        guard let snap = loadAll()[placeId] else { return nil }
        return Place.fromSearchResult(
            name: snap.placeName,
            category: "Place",
            coordinate: CLLocationCoordinate2D(latitude: snap.lat, longitude: snap.lng),
            placeId: snap.placeId
        )
    }

    static func restoreTags(_ labels: [String], for kind: FacilityKind) -> Set<ContributeTagOption> {
        let catalog = ContributeReviewTags.tags(for: kind)
        return Set(labels.compactMap { label in catalog.first { $0.label == label } })
    }

    static func restoreTags(_ labels: [String], forEntrance location: EntranceLocation) -> Set<ContributeTagOption> {
        let catalog = ContributeReviewTags.tags(forEntrance: location)
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
