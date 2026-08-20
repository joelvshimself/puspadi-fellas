import Foundation
import Supabase

struct UserProfileRow: Decodable {
    let id: UUID
    let displayName: String?
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case avatarUrl = "avatar_url"
    }
}

/// Reads/writes `public.profiles` and the `avatars` storage bucket.
final class ProfileService {
    static let shared = ProfileService()

    private static let avatarsBucket = "avatars"

    private let client: SupabaseClient

    private init() {
        client = SupabaseClientProvider.shared
    }

    func fetchCurrent() async throws -> UserProfileRow? {
        let userId = try await client.auth.session.user.id
        let rows: [UserProfileRow] = try await client.from("profiles")
            .select("id, display_name, avatar_url")
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first
    }

    func updateOnboarding(displayName: String, mobilityAids: [String]) async throws {
        let userId = try await client.auth.session.user.id
        try await client.from("profiles")
            .update(ProfileOnboardingUpdate(displayName: displayName, mobilityAids: mobilityAids))
            .eq("id", value: userId)
            .execute()
    }

    func updateDisplayName(_ name: String) async throws {
        let userId = try await client.auth.session.user.id
        try await client.from("profiles")
            .update(ProfileDisplayNameUpdate(displayName: name))
            .eq("id", value: userId)
            .execute()
    }

    func uploadAvatar(jpegData: Data) async throws -> String {
        let userId = try await client.auth.session.user.id
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        let storage = client.storage.from(Self.avatarsBucket)
        try await storage.upload(
            path,
            data: jpegData,
            options: FileOptions(contentType: "image/jpeg", upsert: true)
        )
        let publicURL = try storage.getPublicURL(path: path)
        let urlString = publicURL.absoluteString
        try await client.from("profiles")
            .update(ProfileAvatarUpdate(avatarUrl: urlString))
            .eq("id", value: userId)
            .execute()
        return urlString
    }
}

private struct ProfileOnboardingUpdate: Encodable {
    let displayName: String
    let mobilityAids: [String]
    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case mobilityAids = "mobility_aids"
    }
}

private struct ProfileDisplayNameUpdate: Encodable {
    let displayName: String
    enum CodingKeys: String, CodingKey { case displayName = "display_name" }
}

private struct ProfileAvatarUpdate: Encodable {
    let avatarUrl: String
    enum CodingKeys: String, CodingKey { case avatarUrl = "avatar_url" }
}
