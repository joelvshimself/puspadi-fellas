import CoreLocation
import Foundation
import MapKit

/// Loads nearby POIs for map pins and empty search state.
///
/// Two sources, merged, directory first:
///
///   1. The curated directory (`places-nearby`) — places we imported
///      deliberately. Arrives with a canonical place_id, an address and a
///      grade already resolved.
///   2. MKLocalSearch — everything else in the visible region.
///
/// The merge, rather than one or the other, because each covers the other's
/// gap. MapKit knows about far more places than we have ever curated, but it
/// is inconsistent about the ones we HAVE: the same mall comes back under a
/// different name and a coordinate up to several hundred metres away depending
/// on the region searched, and sometimes not at all. A curated place must not
/// be discoverable only when a third-party index feels like mentioning it.
@MainActor
enum NearbyPlacesService {
    /// Pins for the map.
    ///
    /// Where the directory has coverage, the directory IS the answer — MapKit
    /// is not consulted at all. Its "shopping mall" search is a text query, not
    /// a category filter, so around Kuta it returned RD Leather Bali and a
    /// Playworks store clustered on top of Lippo Mall Kuta. Suppressing those
    /// one at a time is a losing game: the query has no notion of "is actually
    /// a mall", while the directory is a list of malls by construction.
    ///
    /// MapKit still answers where we have curated nothing, so the map is not
    /// empty outside the seeded region — but it is then the fallback rather
    /// than a co-equal source.
    static func search(in region: MKCoordinateRegion, query: String = "shopping mall") async -> [Place] {
        let directory = await directoryPlaces(in: region)
        if !directory.isEmpty { return directory }

        return await mapKitPlaces(in: region, query: query)
    }

    /// Directory places covering the visible region.
    ///
    /// The radius is derived from the region rather than fixed, so a
    /// zoomed-right-in map does not pull in malls 15km away that it would only
    /// have to draw off-screen.
    private static func directoryPlaces(in region: MKCoordinateRegion) async -> [Place] {
        let radius = radiusMeters(for: region)
        let rows = await PlaceDirectoryService.shared.nearby(
            coordinate: region.center,
            radiusMeters: radius
        )
        return rows.map { Place.fromDirectory($0) }
    }

    private static func mapKitPlaces(in region: MKCoordinateRegion, query: String) async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(25).map { item in
                Place.fromSearchResult(
                    name: item.name ?? "Place",
                    category: item.pointOfInterestCategory?.rawValue
                        .replacingOccurrences(of: "MKPOICategory", with: "") ?? "Place",
                    coordinate: item.placemark.coordinate,
                    address: shortAddress(item.placemark),
                    distance: ""
                )
            }
        } catch {
            return []
        }
    }

    /// Drops the MapKit copy of anything the directory already covers.
    ///
    /// Used by the SEARCH sheet, which does still merge the two: someone
    /// typing a name is looking for a specific place and may well mean one we
    /// have not curated. The map, which shows everything in view rather than
    /// what was asked for, takes the directory alone — see `search`.
    ///
    /// This used to compare MapKit's name against the directory name alone,
    /// and that is not how the same venue arrives twice. MapKit says "Park23
    /// Mall" where the directory says "Park23", "Discovery Shopping Mall"
    /// where the directory says "Discovery Mall Bali" — never the same string,
    /// so both drew a pin. Two markers on one building, one carrying the
    /// reviews and the grade, one leading to an empty page, and no way for
    /// anyone tapping to tell which was which.
    ///
    /// The database has always known these are one place; it is what
    /// place_aliases is for. The directory now ships those names with each
    /// place, so the client can apply the same rule instead of a weaker guess.
    ///
    /// Two ways a MapKit result is recognised as already-covered:
    ///
    ///   1. Its name matches the place or any of its aliases, within 1km —
    ///      the alias tier of resolve_place_id, and the distance MapKit's
    ///      drift actually reaches for one venue.
    ///   2. Its name CONTAINS one of those names, within 250m — a tenant.
    ///      "Deus Ex Machina - Discovery Shopping Mall" and "69SLAM Discovery
    ///      Shopping Mall (DSM)" are shops inside the mall, and they render as
    ///      more malls with the same name. The tight radius is what keeps this
    ///      from swallowing a genuinely different place that happens to share
    ///      a word: a tenant is inside the building.
    static func merge(directory: [Place], mapKit: [Place]) -> [Place] {
        guard !directory.isEmpty else { return mapKit }

        let extras = mapKit.filter { candidate in
            let candidateName = normalized(candidate.name)
            guard !candidateName.isEmpty else { return true }

            return !directory.contains { known in
                let metres = distance(known.coordinate, candidate.coordinate)
                let names = known.matchableNames
                if metres <= 1000, names.contains(candidateName) { return true }
                if metres <= 250, names.contains(where: { candidateName.contains($0) }) { return true }
                return false
            }
        }
        return directory + extras
    }

    /// Same normalisation the database applies in resolve_place_id: lowercase,
    /// every non-alphanumeric character dropped. Shared with Place.
    /// matchableNames so the client compares names exactly one way.
    nonisolated static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Half the diagonal of the visible region, floored so a very tight zoom
    /// still returns the malls just outside the frame, and capped so a
    /// zoomed-all-the-way-out map does not ask for a whole country.
    private static func radiusMeters(for region: MKCoordinateRegion) -> Int {
        let latMeters = region.span.latitudeDelta * 111_000
        let lngMeters = region.span.longitudeDelta * 111_000
            * cos(region.center.latitude * .pi / 180)
        let halfDiagonal = (latMeters * latMeters + lngMeters * lngMeters).squareRoot() / 2
        return Int(min(max(halfDiagonal, 2_000), 50_000))
    }

    private static func shortAddress(_ placemark: MKPlacemark) -> String {
        [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
