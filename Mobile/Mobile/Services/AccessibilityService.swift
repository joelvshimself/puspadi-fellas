import Foundation
import Supabase

/// Owner 1 — talks to the `place-accessibility` Edge Function, the only
/// thing allowed to call Google Places. The client only ever sends an
/// already-resolved coordinate (MapKit did the search) — see
/// docs/specs.md §3/§4.1.
final class AccessibilityService {
    static let shared = AccessibilityService()

    private let client: SupabaseClient

    /// The Edge Function returns snake_case keys (best_value, place_id,
    /// osm_accessibility, …) but our models are camelCase. functions.invoke's
    /// default decoder does NOT convert between them, so without this the
    /// response fails to decode and the detail view shows "couldn't load".
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    private struct EnrichRequestBody: Encodable {
        let lat: Double
        let lng: Double
        let name: String?
    }

    func enrich(lat: Double, lng: Double, name: String?) async throws -> PlaceAccessibilityResponse {
        // On-device cache first — avoids re-hitting the Edge Function when the
        // user re-opens a place they viewed recently (see PlaceCacheStore).
        let key = PlaceCacheStore.key(lat: lat, lng: lng)
        if let cached = await PlaceCacheStore.shared.get(key) {
            return cached
        }
        let response: PlaceAccessibilityResponse = try await client.functions.invoke(
            "place-accessibility",
            options: FunctionInvokeOptions(body: EnrichRequestBody(lat: lat, lng: lng, name: name)),
            decoder: decoder
        )
        await PlaceCacheStore.shared.set(key, response)
        return response
    }
}
