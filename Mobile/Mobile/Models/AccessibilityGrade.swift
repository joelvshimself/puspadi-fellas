import Foundation

/// Mirrors one row returned by the `accessibility_grade()` Postgres function
/// (see backend/supabase/migrations) — the confidence-weighted, time-decayed
/// blend across every signal (Google/OSM/review/confirmation) for a feature.
struct AccessibilityFeatureGrade: Identifiable, Decodable {
    let feature: String
    let bestValue: String
    let confidence: Double

    var id: String { feature }

    var featureLabel: String {
        switch feature {
        case "entrance": "Entrance"
        case "parking": "Parking"
        case "restroom": "Restroom"
        case "seating": "Seating"
        default: feature.capitalized
        }
    }

    var valueLabel: String {
        switch bestValue {
        case "yes": "Accessible"
        case "no": "Not accessible"
        case "limited": "Limited access"
        default: "Unknown"
        }
    }

    var symbolName: String {
        switch bestValue {
        case "yes": "checkmark.circle.fill"
        case "no": "xmark.circle.fill"
        case "limited": "exclamationmark.triangle.fill"
        default: "questionmark.circle"
        }
    }
}

/// The `place_cache` row as returned by the Edge Function — only the fields
/// the client actually needs are decoded.
struct PlaceCacheRow: Decodable {
    let placeId: String
    let name: String?
    let lat: Double?
    let lng: Double?
    let osmAccessibility: [String: String]?
}

/// Response shape of `place-accessibility` (see
/// backend/supabase/functions/place-accessibility/index.ts).
struct PlaceAccessibilityResponse: Decodable {
    let status: String
    let place: PlaceCacheRow?
    let grade: [AccessibilityFeatureGrade]?
}
