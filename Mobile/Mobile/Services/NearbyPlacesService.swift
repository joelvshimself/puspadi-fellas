import CoreLocation
import Foundation
import MapKit

/// Loads nearby POIs from MapKit for map pins and empty search state.
@MainActor
enum NearbyPlacesService {
    static func search(in region: MKCoordinateRegion, query: String = "shopping mall") async -> [Place] {
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

    private static func shortAddress(_ placemark: MKPlacemark) -> String {
        [placemark.thoroughfare, placemark.locality, placemark.administrativeArea]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}
