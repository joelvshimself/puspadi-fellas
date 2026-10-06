import Foundation

struct UserProfileRow: Decodable {
    let id: UUID
    let displayName: String?
    let avatarUrl: String?
    let mobilityAids: [String]?
    let pseudonym: String?
    let showRealName: Bool?

    var needsOnboarding: Bool { mobilityAids?.isEmpty ?? true }
}

private struct ProfileUpdate: Encodable {
    var displayName: String?
    var mobilityAids: [String]?
}

private struct AvatarResponse: Decodable { let url: String }

final class ProfileService {
    static let shared = ProfileService()
    private let client = CloudflareAPIClient.shared

    private init() {}

    func fetchCurrent() async throws -> UserProfileRow? {
        let row: UserProfileRow = try await client.get(["v1", "profile"], authenticated: true)
        return row
    }

    func updateOnboarding(displayName: String, mobilityAids: [String]) async throws {
        let _: UserProfileRow = try await client.patch(
            ["v1", "profile"],
            body: ProfileUpdate(displayName: displayName, mobilityAids: mobilityAids)
        )
    }

    func updateDisplayName(_ name: String) async throws {
        let _: UserProfileRow = try await client.patch(
            ["v1", "profile"],
            body: ProfileUpdate(displayName: name, mobilityAids: nil)
        )
    }

    func updateMobilityAids(_ mobilityAids: [String]) async throws {
        let _: UserProfileRow = try await client.patch(
            ["v1", "profile"],
            body: ProfileUpdate(displayName: nil, mobilityAids: mobilityAids)
        )
    }

    func uploadAvatar(jpegData: Data) async throws -> String {
        let response: AvatarResponse = try await client.putData(
            ["v1", "profile", "avatar"],
            data: jpegData,
            contentType: "image/jpeg"
        )
        return response.url
    }
}
