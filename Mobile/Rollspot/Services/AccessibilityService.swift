import Foundation

/// Loads Rollspot's community grade for an Apple Place ID. MapKit owns place
/// discovery; this service never asks the backend to search or enrich a map.
final class AccessibilityService {
    static let shared = AccessibilityService()
    private let client = CloudflareAPIClient.shared
    private init() {}

    func enrich(placeId: String) async throws -> PlaceAccessibilityResponse {
        try await client.get(["v1", "places", placeId, "accessibility"])
    }
}
