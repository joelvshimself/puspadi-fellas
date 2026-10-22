import Foundation
import Shared

/// The profile fields Swift screens read. Built from the shared `ProfileModel` state.
struct UserProfileRow {
    let id: String
    let displayName: String?
    let avatarUrl: String?
    let mobilityAids: [String]?

    var needsOnboarding: Bool { mobilityAids?.isEmpty ?? true }
}

/// Thin Swift entry point to the shared `ProfileModel` (Mobile/shared/.../profile).
/// Validation, saving and the avatar cache-busting all live there, same as Android.
final class ProfileService {
    static let shared = ProfileService()
    private var model: ProfileModel { RollspotServices.sdk.profile }

    private init() {}

    func fetchCurrent() async throws -> UserProfileRow? {
        try await model.load()
        return current
    }

    /// What the shared model last loaded, without a request.
    var current: UserProfileRow? {
        model.state.value.profile.map {
            UserProfileRow(id: $0.id, displayName: $0.displayName, avatarUrl: $0.avatarUrl, mobilityAids: $0.mobilityAids)
        }
    }

    func updateDisplayName(_ name: String) async throws {
        try await model.updateDisplayName(name: name)
    }

    func updateMobilityAids(_ mobilityAids: [String]) async throws {
        try await model.updateMobilityAids(aids: mobilityAids)
    }

    func updateMobilityProfile(_ profile: MobilityProfile) async throws {
        try await model.updateMobilityRole(role: profile.shared)
    }

    /// Returns the new avatar URL (already cache-busted by the shared model).
    func uploadAvatar(jpegData: Data) async throws -> String {
        try await model.uploadAvatar(jpeg: jpegData.asKotlinByteArray())
    }
}
