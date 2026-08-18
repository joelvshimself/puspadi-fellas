import Foundation
import Supabase

/// Manages bookmarking and syncing saved places directly with the Supabase `saved_places` table.
final class SavedPlacesService: ObservableObject {
    static let shared = SavedPlacesService()

    private let client: SupabaseClient

    @Published private(set) var savedPlaceIds: Set<String> = []

    private struct DBSavedPlaceRow: Codable {
        let id: UUID?
        let placeId: String
    }

    private init() {
        client = SupabaseClientProvider.shared
        Task { await fetchSavedPlaceIds() }
    }

    @MainActor
    func fetchSavedPlaceIds() async {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let rows: [DBSavedPlaceRow] = try await client.from("saved_places")
                .select("id, place_id")
                .execute()
                .value
            self.savedPlaceIds = Set(rows.map { $0.placeId })
        } catch {
            print("SavedPlacesService: Failed to fetch saved places from Supabase: \(error)")
        }
    }

    func isSaved(placeId: String) -> Bool {
        savedPlaceIds.contains(placeId)
    }

    @MainActor
    func toggleSave(placeId: String) async {
        if savedPlaceIds.contains(placeId) {
            savedPlaceIds.remove(placeId)
            do {
                try await client.from("saved_places")
                    .delete()
                    .eq("place_id", value: placeId)
                    .execute()
            } catch {
                print("SavedPlacesService: Failed to delete saved place: \(error)")
            }
        } else {
            savedPlaceIds.insert(placeId)
            do {
                let body = ["place_id": placeId]
                try await client.from("saved_places")
                    .insert(body)
                    .execute()
            } catch {
                print("SavedPlacesService: Failed to insert saved place: \(error)")
            }
        }
    }
}
