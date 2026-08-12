import Foundation
import Supabase

/// Owner 1 — talks to the `place-accessibility` Edge Function, the only
/// thing allowed to call Google Places. The client only ever sends an
/// already-resolved coordinate (MapKit did the search) — see
/// docs/specs.md §3/§4.1.
final class AccessibilityService {
    static let shared = AccessibilityService()

    private let client: SupabaseClient

    private init() {
        client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.anonKey)
    }

    private struct EnrichRequestBody: Encodable {
        let lat: Double
        let lng: Double
        let name: String?
    }

    func enrich(lat: Double, lng: Double, name: String?) async throws -> PlaceAccessibilityResponse {
        try await client.functions.invoke(
            "place-accessibility",
            options: FunctionInvokeOptions(body: EnrichRequestBody(lat: lat, lng: lng, name: name))
        )
    }
}
