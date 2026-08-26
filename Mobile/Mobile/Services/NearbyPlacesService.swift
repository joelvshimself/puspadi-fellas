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
    static func search(in region: MKCoordinateRegion, query: String = "shopping mall") async -> [Place] {
        async let directory = directoryPlaces(in: region)
        async let mapKit = mapKitPlaces(in: region, query: query)

        return merge(directory: await directory, mapKit: await mapKit)
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
    /// Without this the map shows two pins for Beachwalk — one carrying the
    /// seeded id and its grade, one carrying MapKit's drifted coordinate and
    /// no grade — and a tap lands on whichever happens to be on top. The
    /// backend has the same problem and solves it the same way
    /// (resolve_place_id: a name match within a radius), so the client uses
    /// the same rule rather than inventing a second one that disagrees.
    ///
    /// 1km, matching the alias tier of resolve_place_id, because that is the
    /// distance MapKit's drift actually reaches for one venue — the project's
    /// own place_cache holds rows ~600m apart that are the same mall.
    static func merge(directory: [Place], mapKit: [Place]) -> [Place] {
        guard !directory.isEmpty else { return mapKit }

        let extras = mapKit.filter { candidate in
            !directory.contains { known in
                normalized(known.name) == normalized(candidate.name)
                    && distance(known.coordinate, candidate.coordinate) <= 1000
            }
        }
        return directory + extras
    }

    /// Same normalisation the database applies in resolve_place_id: lowercase,
    /// every non-alphanumeric character dropped. "Mal Bali Galeria" and
    /// "Mall Bali Galeria" still differ here — that pair is handled by the
    /// alias table server-side, which the client has no copy of. It costs a
    /// duplicate pin in the rare case, which is the right way round: a
    /// duplicate pin is visible and harmless, a wrongly merged one hides a
    /// real place.
    private static func normalized(_ name: String) -> String {
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
