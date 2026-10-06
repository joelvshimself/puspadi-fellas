import Foundation

struct PlacePhoto: Identifiable, Hashable, Decodable {
    let id: UUID
    let url: String
    let source: String
    let credit: String?
    let sortOrder: Int

    var imageURL: URL? { URL(string: url) }
    var requiresCredit: Bool { credit?.isEmpty == false }
}

@MainActor
final class PlacePhotoService {
    static let shared = PlacePhotoService()
    private let client = CloudflareAPIClient.shared
    private init() {}

    func photos(for placeId: String) async -> [PlacePhoto] {
        do {
            let rows: [PlacePhoto] = try await client.get(["v1", "places", placeId, "photos"])
            return rows
        } catch {
            print("[PlacePhotoService] Fetch failed: \(error)")
            return []
        }
    }

    func invalidate(_ placeId: String) {}
}
