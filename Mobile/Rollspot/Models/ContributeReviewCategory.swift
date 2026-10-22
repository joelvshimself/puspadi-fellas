import Foundation

/// Mirrors `ContributeReviewCategory` in the shared Kotlin module.
enum ContributeReviewCategory: String, CaseIterable, Identifiable, Hashable {
    case entrance
    case elevator
    case toilet
    case outdoorPathways
    case seating
    case parking

    var id: String { rawValue }

    static let menuOrder: [ContributeReviewCategory] = allCases
    static let supplemental: [ContributeReviewCategory] = [.outdoorPathways, .seating, .parking]

    var menuTitle: String {
        switch self {
        case .entrance: "Entrance"
        case .elevator: "Elevators"
        case .toilet: "Toilet"
        case .outdoorPathways: "Outdoor Pathways"
        case .seating: "Seating"
        case .parking: "Parking"
        }
    }

    var isSupplemental: Bool { Self.supplemental.contains(self) }

    init?(facilityKind: FacilityKind) {
        switch facilityKind {
        case .entrance: self = .entrance
        case .elevator: self = .elevator
        case .toilet: self = .toilet
        }
    }

    var facilityKind: FacilityKind? {
        switch self {
        case .entrance: .entrance
        case .elevator: .elevator
        case .toilet: .toilet
        default: nil
        }
    }
}
