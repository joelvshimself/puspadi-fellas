import Foundation
import Shared

/// The two roles shown in My Account. What each one stores, and how stored answers map
/// back to a role, is the shared `MobilityRole` (same on Android).
enum MobilityProfile: String, CaseIterable, Identifiable, Hashable {
    case wheelchairUser
    case communityContributor

    var id: String { rawValue }

    var titleKey: String { shared.label }

    var shared: MobilityRole {
        switch self {
        case .wheelchairUser: .wheelchairUser
        case .communityContributor: .communityContributor
        }
    }

    static func from(aids: [String]?) -> MobilityProfile? {
        switch MobilityRole.companion.fromAids(aids: aids ?? []) {
        case .wheelchairUser: .wheelchairUser
        case .communityContributor: .communityContributor
        default: nil
        }
    }
}
