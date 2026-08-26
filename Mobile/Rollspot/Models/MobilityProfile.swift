import Foundation

/// High-level mobility profile shown in My Account (maps to `profiles.mobility_aids`).
enum MobilityProfile: String, CaseIterable, Identifiable, Hashable {
    case wheelchairUser
    case communityContributor

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .wheelchairUser: return "Wheelchair User"
        case .communityContributor: return "Community Contributor"
        }
    }

    /// Stored `mobility_aids` values for this profile.
    var storageAids: [String] {
        switch self {
        case .wheelchairUser: return ["Wheelchair"]
        case .communityContributor: return ["No mobility aid"]
        }
    }

    static func from(aids: [String]?) -> MobilityProfile? {
        guard let aids, !aids.isEmpty else { return nil }
        if aids.contains("Wheelchair") { return .wheelchairUser }
        return .communityContributor
    }
}
