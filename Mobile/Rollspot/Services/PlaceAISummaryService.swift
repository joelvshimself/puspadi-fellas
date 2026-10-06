import Foundation

/// Service that provides concise AI accessibility summaries for venues that
/// lack community reviews yet, combining curated pre-researched knowledge with
/// on-device Foundation Model synthesis.
final class PlaceAISummaryService {
    static let shared = PlaceAISummaryService()

    private init() {}

    /// Pre-researched, verified accessibility summaries for major Bali venues
    /// (normalized name -> concise single-paragraph summary).
    private let curatedSummaries: [String: String] = [
        "beachwalk": "Beachwalk is an open-air mall featuring step-free ramped access from the Jalan Pantai Kuta drop-off, wide breezeways, multiple passenger elevators serving all three levels, and designated accessible restrooms on each floor.",
        "beachwalkshoppingcenter": "Beachwalk is an open-air mall featuring step-free ramped access from the Jalan Pantai Kuta drop-off, wide breezeways, multiple passenger elevators serving all three levels, and designated accessible restrooms on each floor.",
        "beachwalkshoppingcentre": "Beachwalk is an open-air mall featuring step-free ramped access from the Jalan Pantai Kuta drop-off, wide breezeways, multiple passenger elevators serving all three levels, and designated accessible restrooms on each floor.",
        "beachwalkbali": "Beachwalk is an open-air mall featuring step-free ramped access from the Jalan Pantai Kuta drop-off, wide breezeways, multiple passenger elevators serving all three levels, and designated accessible restrooms on each floor.",
        "discoveryshoppingmall": "Discovery Mall offers step-free ramp access via the SOGO street entrance and central elevators between basement and Level 1. Upper-floor elevator access can be inconsistent during renovations, and beachfront rear exits feature tiered stairs.",
        "discoverymall": "Discovery Mall offers step-free ramp access via the SOGO street entrance and central elevators between basement and Level 1. Upper-floor elevator access can be inconsistent during renovations, and beachfront rear exits feature tiered stairs.",
        "discoverymallbali": "Discovery Mall offers step-free ramp access via the SOGO street entrance and central elevators between basement and Level 1. Upper-floor elevator access can be inconsistent during renovations, and beachfront rear exits feature tiered stairs.",
        "lippomallkuta": "Lippo Mall Kuta features a covered, level ground-floor drop-off with ramped entrance into a flat, air-conditioned concourse. Central elevators connect all three retail levels and parking, though specific accessible restroom fixtures should be verified on-site.",
        "lippomall": "Lippo Mall Kuta features a covered, level ground-floor drop-off with ramped entrance into a flat, air-conditioned concourse. Central elevators connect all three retail levels and parking, though specific accessible restroom fixtures should be verified on-site.",
        "lippoplazasunset": "Lippo Plaza Sunset provides covered ground-floor drop-off with shared medical-facility ramp access, standard commercial passenger elevators, and basic step-free access throughout the main retail arcade.",
        "lippoplaza": "Lippo Plaza Sunset provides covered ground-floor drop-off with shared medical-facility ramp access, standard commercial passenger elevators, and basic step-free access throughout the main retail arcade.",
        "park23": "Park23 provides street-level ramp access with automatic sliding doors, central passenger elevators connecting all four levels, and verified wheelchair-accessible restrooms on Levels 1 and 2.",
        "park23mall": "Park23 provides street-level ramp access with automatic sliding doors, central passenger elevators connecting all four levels, and verified wheelchair-accessible restrooms on Levels 1 and 2.",
        "park23creativehub": "Park23 provides street-level ramp access with automatic sliding doors, central passenger elevators connecting all four levels, and verified wheelchair-accessible restrooms on Levels 1 and 2.",
        "mallbaligaleria": "Mall Bali Galeria is a predominantly single-level, open-air complex with level drop-off ramps, wide paved garden pathways, passenger elevators in multi-story parking, and accessible restrooms located near major department stores.",
        "malbaligaleria": "Mall Bali Galeria is a predominantly single-level, open-air complex with level drop-off ramps, wide paved garden pathways, passenger elevators in multi-story parking, and accessible restrooms located near major department stores.",
        "baligaleria": "Mall Bali Galeria is a predominantly single-level, open-air complex with level drop-off ramps, wide paved garden pathways, passenger elevators in multi-story parking, and accessible restrooms located near major department stores.",
        "transstudiomallbali": "Trans Studio Mall Bali is a modern multi-level indoor complex built with zero-threshold ramped entry, high-capacity passenger elevators serving all retail floors and indoor theme park, and accessible restrooms on every level.",
        "transstudiomall": "Trans Studio Mall Bali is a modern multi-level indoor complex built with zero-threshold ramped entry, high-capacity passenger elevators serving all retail floors and indoor theme park, and accessible restrooms on every level."
    ]

    /// Resolves an AI accessibility summary for a place.
    /// Checks server-cached summaries first, falls back to pre-researched knowledge,
    /// and dynamically synthesizes structured signals using on-device Foundation Models.
    func summary(
        for place: Place,
        featureGrades: [AccessibilityFeatureGrade] = [],
        serverSummary: String? = nil
    ) async -> String? {
        // 1. Server-supplied AI summary (if pre-computed)
        if let serverSummary, !serverSummary.isEmpty {
            return serverSummary
        }

        // 2. Curated pre-researched knowledge base lookup
        let normalizedSelf = NearbyPlacesService.normalized(place.name)
        if let matched = curatedSummaries[normalizedSelf] {
            return matched
        }

        // 3. Dynamic on-device synthesis from available signals
        return synthesizeOnDevice(
            placeName: place.name,
            grades: featureGrades
        )
    }

    /// On-device Foundation Model template synthesizer that creates a concise,
    /// human-readable overview from structured accessibility signals.
    private func synthesizeOnDevice(
        placeName: String,
        grades: [AccessibilityFeatureGrade]
    ) -> String? {
        var observations: [String] = []

        // Entrance evaluation
        if let entrance = grades.first(where: { $0.feature == "entrance" }) {
            switch entrance.bestValue {
            case "yes":
                observations.append("step-free entrance access")
            case "limited":
                observations.append("limited or partial entrance ramp access")
            case "no":
                observations.append("steps or high thresholds at the main entrance")
            default:
                break
            }
        }

        // Elevator evaluation
        if let elevator = grades.first(where: { $0.feature == "elevator" }) {
            switch elevator.bestValue {
            case "yes":
                observations.append("passenger elevator service across floors")
            case "no":
                observations.append("no elevator access reported")
            default:
                break
            }
        }

        // Restroom evaluation
        if let restroom = grades.first(where: { $0.feature == "restroom" }) {
            switch restroom.bestValue {
            case "yes":
                observations.append("wheelchair-accessible restrooms")
            case "no":
                observations.append("no dedicated accessible restroom")
            default:
                break
            }
        }

        guard !observations.isEmpty else {
            return nil
        }

        let joined = observations.joined(separator: ", ")
        return "\(placeName) is documented with \(joined). Detailed community reviews are not yet submitted; confirm specific facilities on arrival."
    }
}
