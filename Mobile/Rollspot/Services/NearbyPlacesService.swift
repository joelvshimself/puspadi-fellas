import CoreLocation
import Foundation
import MapKit

/// Apple MapKit is the sole place-discovery and rendering source.
@MainActor
enum NearbyPlacesService {
    static func search(in region: MKCoordinateRegion, query: String = "shopping mall") async -> [Place] {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = region
        request.resultTypes = [.pointOfInterest, .address]

        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.prefix(25).compactMap { makePlace(from: $0) }
        } catch {
            print("[NearbyPlacesService] MapKit search failed: \(error)")
            return []
        }
    }

    static func makePlace(from item: MKMapItem, distance: String = "") -> Place? {
        guard let placeId = item.identifier?.rawValue else { return nil }
        return Place.fromSearchResult(
            name: item.name ?? "Place",
            category: item.pointOfInterestCategory?.rawValue
                .replacingOccurrences(of: "MKPOICategory", with: "") ?? "Place",
            coordinate: item.placemark.coordinate,
            address: shortAddress(item.placemark),
            distance: distance,
            applePlaceId: placeId,
            phone: item.phoneNumber,
            website: item.url?.absoluteString
        )
    }

    nonisolated static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }

    private static func shortAddress(_ placemark: MKPlacemark) -> String {
        [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
