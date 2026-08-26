import CoreLocation
import Foundation
import Supabase

/// Reads the curated place directory from the `places-nearby` Edge Function.
///
/// Everything the app knew about where places ARE came from MKLocalSearch.
/// That works, until you have data of your own: the Bali mall seed is 22 malls
/// imported deliberately, with addresses, hours and grades, and MapKit returns
/// a different subset of them depending on the region it is asked about, the
/// spelling it decides on, and the day. Places we have deliberately curated
/// should not be discoverable only when a third-party index happens to feel
/// like mentioning them.
///
/// So the directory is the authority for what it covers, and MapKit stays as
/// the long tail for everything it doesn't — see NearbyPlacesService.search,
/// which merges the two.
@MainActor
final class PlaceDirectoryService {
    static let shared = PlaceDirectoryService()

    private let client: SupabaseClient
    /// One entry per rounded (centre, radius). The map re-searches on every
    /// settled pan, and the directory changes about as often as someone builds
    /// a new mall — re-fetching it per pan would be pure waste.
    private var cache: [String: (places: [DirectoryPlace], at: Date)] = [:]
    private var inFlight: [String: Task<[DirectoryPlace], Never>] = [:]

    private static let cacheTTL: TimeInterval = 60 * 60

    private init() {
        client = SupabaseClientProvider.shared
    }

    struct DirectoryPlace: Decodable {
        let placeId: String
        let name: String
        let lat: Double
        let lng: Double
        let address: String?
        let city: String?
        let category: String
        let phone: String?
        let website: String?
        let openingHours: String?
        let levels: Int?
        let imageUrl: String?
        let imageAttribution: String?
        let attribution: String?
        let distanceMeters: Int
        /// "yes" / "limited" / "no" / "unknown" — the worst verdict held for
        /// the place, already collapsed server-side.
        let grade: String
        let gradedFeatures: Int
        /// Every name this place is known by, straight from place_aliases.
        /// Used to recognise — and drop — the MapKit result that is this same
        /// venue under a different spelling. Optional so a client running
        /// against a backend that predates the field still decodes.
        let aliases: [String]?

        var coordinate: CLLocationCoordinate2D {
            CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }

        var overallGrade: OverallAccessibility {
            guard gradedFeatures > 0 else { return .noData }
            switch grade {
            case "yes": return .accessible
            case "limited": return .partiallyAccessible
            case "no": return .notAccessible
            default: return .noData
            }
        }
    }

    private struct Response: Decodable {
        let status: String
        let places: [DirectoryPlace]
        let attribution: [String]
    }

    private struct RequestBody: Encodable {
        let lat: Double
        let lng: Double
        let radiusMeters: Int
        let limit: Int
    }

    /// Directory places near a coordinate. Never throws: the directory is an
    /// enhancement to the MapKit results, and a map that fails to draw because
    /// a supplementary lookup failed would be a worse map than one that draws
    /// with fewer pins.
    func nearby(
        coordinate: CLLocationCoordinate2D,
        radiusMeters: Int = 15_000,
        limit: Int = 100
    ) async -> [DirectoryPlace] {
        let key = Self.cacheKey(coordinate, radiusMeters)

        if let hit = cache[key], Date().timeIntervalSince(hit.at) < Self.cacheTTL {
            return hit.places
        }
        // Same reasoning as AccessibilityService's coalescer: the map sweep and
        // the search sheet ask about the same region at the same moment, and
        // two identical requests are one request too many.
        if let existing = inFlight[key] {
            return await existing.value
        }

        let task = Task { [client] () -> [DirectoryPlace] in
            do {
                let response: Response = try await client.functions.invoke(
                    "places-nearby",
                    options: FunctionInvokeOptions(
                        body: RequestBody(
                            lat: coordinate.latitude,
                            lng: coordinate.longitude,
                            radiusMeters: radiusMeters,
                            limit: limit
                        )
                    ),
                    decoder: JSONDecoder()
                )
                return response.places
            } catch {
                print("[PlaceDirectoryService] nearby failed: \(error)")
                return []
            }
        }
        inFlight[key] = task
        let places = await task.value
        inFlight[key] = nil

        // Only a real answer is worth caching for an hour. Caching an empty
        // result from a failed request would hide the directory until the TTL
        // expired.
        if !places.isEmpty {
            cache[key] = (places, Date())
        }
        return places
    }

    /// ~1km buckets, so a small pan reuses the previous answer instead of
    /// minting a new cache key for every pixel of movement.
    private static func cacheKey(_ coordinate: CLLocationCoordinate2D, _ radius: Int) -> String {
        String(
            format: "%.2f_%.2f_%d",
            coordinate.latitude,
            coordinate.longitude,
            radius
        )
    }
}

extension Place {
    /// Builds a Place from a curated directory row.
    ///
    /// Unlike a MapKit result this arrives with its canonical place_id and its
    /// grade already resolved, so the map can colour the pin without spending
    /// an enrich call on it.
    static func fromDirectory(
        _ row: PlaceDirectoryService.DirectoryPlace,
        distance: String = ""
    ) -> Place {
        Place(
            id: UUID(),
            name: row.name,
            category: row.category,
            distance: distance,
            address: row.address ?? row.city ?? "",
            ratingLabel: "",
            summary: "",
            description: "",
            coordinate: row.coordinate,
            accentColor: .accentColor,
            gallerySymbols: [],
            facilitySymbols: [],
            elevatorDetails: [],
            reviewsSummary: "",
            grade: row.overallGrade,
            isLiveResult: true,
            directoryPlaceId: row.placeId,
            knownNames: [row.name] + (row.aliases ?? []),
            phone: row.phone,
            website: row.website,
            openingHours: row.openingHours,
            dataAttribution: row.attribution
        )
    }
}
