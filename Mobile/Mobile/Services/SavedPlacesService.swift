import Foundation
import Supabase

/// Manages bookmarking and syncing saved places directly with the Supabase `saved_places` table.
@MainActor
final class SavedPlacesService: ObservableObject {
    static let shared = SavedPlacesService()

    private let client: SupabaseClient

    @Published private(set) var savedPlaceIds: Set<String> = []

    /// What a toggle actually did. The old version returned nothing and only
    /// `print`ed failures, so a rejected write looked exactly like a save.
    enum SaveOutcome: Equatable {
        case saved
        case removed
        case needsSignIn
        case failed(String)
    }

    private struct DBSavedPlaceRow: Codable {
        let id: UUID?
        let placeId: String
    }

    /// `saved_places.user_id` is `not null` and RLS checks it against
    /// `auth.uid()`, so it has to travel with the insert — omitting it is why
    /// nothing was persisting once auth was switched on.
    private struct NewSavedPlace: Encodable {
        let userId: UUID
        let placeId: String

        enum CodingKeys: String, CodingKey {
            case userId = "user_id"
            case placeId = "place_id"
        }
    }

    private init() {
        client = SupabaseClientProvider.shared
        // The initial fetch used to fire from here unconditionally, which raced
        // the session restore: the request went out anonymous and RLS returned
        // nothing. Follow the auth state instead — `emitLocalSessionAsInitialSession`
        // means the restored session arrives on this stream too.
        Task { [weak self] in
            for await (_, session) in SupabaseClientProvider.shared.auth.authStateChanges {
                guard let self else { return }
                if session == nil {
                    self.savedPlaceIds = []
                } else {
                    await self.fetchSavedPlaceIds()
                }
            }
        }
    }

    func fetchSavedPlaceIds() async {
        guard client.auth.currentUser != nil else {
            savedPlaceIds = []
            return
        }
        do {
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

    @discardableResult
    func toggleSave(placeId: String, place: Place? = nil) async -> SaveOutcome {
        guard let userId = client.auth.currentUser?.id else { return .needsSignIn }

        let wasSaved = savedPlaceIds.contains(placeId)
        // Kept so the rollback below can put the row back even when the caller
        // passed no `place` to rebuild it from.
        let snapshot = SavedPlaceSnapshotStore.place(for: placeId) ?? place

        apply(saved: !wasSaved, placeId: placeId, place: place ?? snapshot)

        do {
            if wasSaved {
                try await client.from("saved_places")
                    .delete()
                    .eq("user_id", value: userId)
                    .eq("place_id", value: placeId)
                    .execute()
                return .removed
            } else {
                // Upsert, not insert: `unique (user_id, place_id)` makes a
                // double-tap (or a stale local set) a duplicate-key error
                // rather than a no-op.
                try await client.from("saved_places")
                    .upsert(NewSavedPlace(userId: userId, placeId: placeId), onConflict: "user_id,place_id")
                    .execute()
                return .saved
            }
        } catch {
            // The optimistic edit above has to come back out, or the bookmark
            // stays filled for a row the database never accepted.
            apply(saved: wasSaved, placeId: placeId, place: snapshot)
            print("SavedPlacesService: Failed to \(wasSaved ? "delete" : "insert") saved place: \(error)")
            return .failed(error.localizedDescription)
        }
    }

    private func apply(saved: Bool, placeId: String, place: Place?) {
        if saved {
            savedPlaceIds.insert(placeId)
            if let place { SavedPlaceSnapshotStore.save(place, placeId: placeId) }
        } else {
            savedPlaceIds.remove(placeId)
            SavedPlaceSnapshotStore.remove(placeId: placeId)
        }
    }
}
