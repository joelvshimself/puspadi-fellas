import Shared
import SwiftUI

/// One community-derived accessibility grade returned by the Cloudflare API.
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

/// Stable place identity returned by the API. Apple Maps remains responsible
/// for all place names, coordinates, addresses, and other display data.
struct PlaceCacheRow: Codable {
    let id: String?
}

/// Response shape of `GET /v1/places/:placeId/accessibility`.
struct PlaceAccessibilityResponse: Codable {
    let status: String
    let place: PlaceCacheRow?
    let grade: [AccessibilityFeatureGrade]?
}

/// Collapses per-feature grades into the single badge shown on a pin or a
/// detail header.
///
/// THE ONE RULE. The map pin and the detail page used to each collapse the
/// same feature rows their own way — the pin took the worst verdict actually
/// held (server-side, in places_directory_nearby), while the detail page
/// required EVERY feature to be "yes", so one `unknown` feature quietly
/// downgraded a place. The same mall was green on the map and "Moderately
/// accessible" when you opened it. Both now call this.
///
/// `unknown` features are ignored rather than counted against the place: not
/// knowing whether a restroom is accessible is not evidence that it is not,
/// and treating it as such punishes exactly the under-documented places a
/// contributor should be sent to.
///
/// The rule itself lives in the shared module (places/Accessibility.kt) so
/// Android applies exactly the same one.
func collapseAccessibility(_ grades: [AccessibilityFeatureGrade]) -> OverallAccessibility {
    let shared = grades.map { FeatureGrade(feature: $0.feature, bestValue: $0.bestValue, confidence: $0.confidence) }
    return OverallAccessibility(AccessibilityKt.collapseAccessibility(grades: shared))
}

/// Overall accessibility badge shown on the grade card (green/yellow/red).
/// TODO(backend): mirrors the Boolean Grading Matrix (E/V/T →
/// Fully/Partially/Not Accessible) conceptually, but is currently derived
/// client-side from the per-feature rows as a placeholder — see
/// PlaceDetailView.overallGrade. Replace with a real backend-computed field
/// once available.
enum OverallAccessibility: String, CaseIterable, Identifiable, Hashable {
    case accessible
    case partiallyAccessible
    case notAccessible
    /// No signal at all yet (distinct from "not accessible" — this means
    /// unknown, not confirmed-inaccessible). Matches the mockup's 4th
    /// badge state; not yet surfaced by the live grade card (that one only
    /// ever has the first 3, since it hides itself entirely when `grade`
    /// is empty — see PlaceDetailView.accessibilityGradeSection).
    case noData

    var id: String { rawValue }

    var label: String {
        switch self {
        case .accessible: "Accessible".localized
        case .partiallyAccessible: "Moderately Accessible".localized
        case .notAccessible: "Not Accessible".localized
        case .noData: "No Data Available".localized
        }
    }

    /// Used by the live grade card's existing badge (systemGray4 for a 4th
    /// case, since that badge never actually renders `.noData` today).
    var color: Color {
        switch self {
        case .accessible: .green
        case .partiallyAccessible: .orange
        case .notAccessible: .red
        case .noData: Color(.systemGray)
        }
    }

    var symbolName: String {
        switch self {
        case .accessible: "hand.thumbsup.fill"
        case .partiallyAccessible: "hand.thumbsdown.hand.thumbsup.fill"
        case .notAccessible: "hand.thumbsdown.fill"
        case .noData: "questionmark.circle.fill"
        }
    }

    /// Exact Figma badge palette (separate light background + saturated
    /// foreground pair per state, not a single `color.opacity(...)` tint).
    var badgeBackground: Color {
        switch self {
        case .accessible: Color(red: 223 / 255, green: 245 / 255, blue: 226 / 255) // #DFF5E2
        case .partiallyAccessible: Color(red: 255 / 255, green: 232 / 255, blue: 187 / 255) // #FFE8BB
        case .notAccessible: Color(red: 255 / 255, green: 231 / 255, blue: 229 / 255) // #FFE7E5
        case .noData: Color(red: 231 / 255, green: 231 / 255, blue: 231 / 255) // #E7E7E7
        }
    }

    var badgeForeground: Color {
        switch self {
        case .accessible: Color(red: 10 / 255, green: 110 / 255, blue: 23 / 255) // #0A6E17
        case .partiallyAccessible: Color(red: 200 / 255, green: 107 / 255, blue: 0 / 255) // #C86B00
        case .notAccessible: Color(red: 222 / 255, green: 54 / 255, blue: 44 / 255) // #DE362C
        case .noData: Color(red: 95 / 255, green: 95 / 255, blue: 95 / 255) // #5F5F5F
        }
    }
}
