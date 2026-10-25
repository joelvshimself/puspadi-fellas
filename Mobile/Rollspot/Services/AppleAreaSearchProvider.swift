import CoreLocation
import Foundation
import MapKit
import Shared

/// Addresses and areas from Apple Maps search, for the shared `MapModel` to list after
/// Rollspot's own places. `.address` only: Apple's points of interest never mix with
/// our directory, they'd have no grades and no Rollspot IDs. Android: AndroidAreaSearchProvider.
final class AppleAreaSearchProvider: NSObject, AreaSearchProvider {
    /// Wide enough that "Tokyo" from Bali still finds Tokyo; Apple still ranks nearer matches first.
    private static let searchSpanDegrees = 60.0

    /// SKIE exposes the Kotlin `suspend fun search` to Swift implementers under this name.
    func __search(query: String, nearLat: Double, nearLng: Double) async throws -> [AreaResult] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .address
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: nearLat, longitude: nearLng),
            span: MKCoordinateSpan(latitudeDelta: Self.searchSpanDegrees, longitudeDelta: Self.searchSpanDegrees)
        )
        // No match, offline or throttled: the map just lists places without areas.
        let items = (try? await MKLocalSearch(request: request).start().mapItems) ?? []
        return items.compactMap(Self.area(from:))
    }

    private static func area(from item: MKMapItem) -> AreaResult? {
        let placemark = item.placemark
        guard let title = item.name ?? placemark.locality ?? placemark.administrativeArea ?? placemark.country else {
            return nil
        }
        var seen: Set<String> = [title.lowercased()]
        let subtitle = [placemark.locality, placemark.administrativeArea, placemark.country]
            .compactMap { $0 }
            .filter { seen.insert($0.lowercased()).inserted }
            .joined(separator: ", ")
        return AreaResult(
            title: title,
            subtitle: subtitle,
            lat: placemark.coordinate.latitude,
            lng: placemark.coordinate.longitude,
            kind: kind(of: placemark)
        )
    }

    private static func kind(of placemark: MKPlacemark) -> AreaKind {
        if placemark.thoroughfare != nil || placemark.subThoroughfare != nil { return .address }
        if placemark.subLocality != nil { return .neighborhood }
        if placemark.locality != nil { return .city }
        if placemark.administrativeArea != nil { return .region }
        return .country
    }
}
