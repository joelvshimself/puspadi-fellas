import Foundation
import Supabase

/// One curated photograph of a venue.
///
/// Distinct from a ReviewPhoto, which documents a specific facility somebody
/// walked up to — this is a picture of the place itself, and it carries a
/// credit that has to be shown wherever it is.
struct PlacePhoto: Identifiable, Hashable, Decodable {
    let id: UUID
    let url: String
    let source: String
    let credit: String?
    let sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id, url, source, credit
        case sortOrder = "sort_order"
    }

    var imageURL: URL? { URL(string: url) }

    /// True when the image belongs to the venue rather than to an open
    /// dataset, so the credit is not optional decoration.
    var requiresCredit: Bool { source == "official_website" }
}

/// Reads `place_photos` for a place.
///
/// Straight through PostgREST rather than an Edge Function: the table is
/// publicly readable by policy and nothing needs joining or hiding, so a
/// function would be a hop for its own sake.
@MainActor
final class PlacePhotoService {
    static let shared = PlacePhotoService()

    private let client: SupabaseClient
    private var cache: [String: [PlacePhoto]] = [:]

    private init() {
        client = SupabaseClientProvider.shared
    }

    /// Never throws — a place with no venue photo is the normal case, and the
    /// screen has Mapillary and Look Around behind it either way.
    func photos(for placeId: String) async -> [PlacePhoto] {
        if let hit = cache[placeId] { return hit }
        do {
            let rows: [PlacePhoto] = try await client
                .from("place_photos")
                .select("id, url, source, credit, sort_order")
                .eq("place_id", value: placeId)
                .order("sort_order", ascending: true)
                .execute()
                .value
            cache[placeId] = rows
            return rows
        } catch {
            print("[PlacePhotoService] photos(for:) failed: \(error)")
            return []
        }
    }

    func invalidate(_ placeId: String) {
        cache[placeId] = nil
    }
}
