import SwiftUI

/// Mirrors one row returned by the `accessibility_grade()` Postgres function
/// (see backend/supabase/migrations) — the confidence-weighted, time-decayed
/// blend across every signal (Google/OSM/review/confirmation) for a feature.
struct AccessibilityFeatureGrade: Identifiable, Codable {
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
struct PlaceCacheRow: Codable {
    let placeId: String
    let name: String?
    let lat: Double?
    let lng: Double?
    let osmAccessibility: [String: String]?
    /// Permanent Supabase Storage URL of a cached Mapillary photo (CC BY-SA),
    /// nil when there's no coverage. See backend tryCacheMapillaryImage.
    let imageUrl: String?
    let imageAttribution: String?
}

/// Response shape of `place-accessibility` (see
/// backend/supabase/functions/place-accessibility/index.ts).
struct PlaceAccessibilityResponse: Codable {
    let status: String
    let place: PlaceCacheRow?
    let grade: [AccessibilityFeatureGrade]?
}

/// Overall accessibility badge shown on the grade card (green/yellow/red).
/// TODO(backend): mirrors the Boolean Grading Matrix (E/V/T →
/// Fully/Partially/Not Accessible) conceptually, but is currently derived
/// client-side from the per-feature rows as a placeholder — see
/// PlaceDetailView.overallGrade. Replace with a real backend-computed field
/// once available.
enum OverallAccessibility {
    case accessible
    case partiallyAccessible
    case notAccessible

    var label: String {
        switch self {
        case .accessible: "Accessible"
        case .partiallyAccessible: "Partially Accessible"
        case .notAccessible: "Not Accessible"
        }
    }

    var color: Color {
        switch self {
        case .accessible: .green
        case .partiallyAccessible: .yellow
        case .notAccessible: .red
        }
    }
}
