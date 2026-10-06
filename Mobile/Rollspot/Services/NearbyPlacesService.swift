import CoreLocation
import Foundation
import MapKit
import Shared

/// Places come from Rollspot's own directory (OpenStreetMap data, synced by the
/// backend) through the shared module, so iOS and Android show the same places
/// with the same IDs. Apple Maps only draws the map.
@MainActor
enum NearbyPlacesService {
    static func search(in region: MKCoordinateRegion) async -> [Place] {
        // Cover the visible span: half its larger side, in meters (1° latitude ≈ 111 km).
        let spanMeters = max(region.span.latitudeDelta, region.span.longitudeDelta) * 111_000
        let radius = Int32(min(max(spanMeters / 2, 1_000), 20_000))
        do {
            let places = try await RollspotServices.sdk.places.nearby(
                lat: region.center.latitude,
                lng: region.center.longitude,
                radiusMeters: radius
            )
            return places.map { makePlace(from: $0, distanceFrom: region.center) }
        } catch {
            print("[NearbyPlacesService] Nearby places failed: \(error)")
            return []
        }
    }

    /// Text search over the directory, nearest matches first. Throws so the sheet can show the error.
    static func search(text: String, near center: CLLocationCoordinate2D) async throws -> [Place] {
        let places = try await RollspotServices.sdk.places.search(
            query: text,
            nearLat: KotlinDouble(value: center.latitude),
            nearLng: KotlinDouble(value: center.longitude)
        )
        return places.map { makePlace(from: $0, distanceFrom: center) }
    }

    static func place(key: String) async -> Place? {
        guard let place = try? await RollspotServices.sdk.places.place(key: key) else { return nil }
        return makePlace(from: place, distanceFrom: nil)
    }

    static func makePlace(from place: Shared.Place, distanceFrom origin: CLLocationCoordinate2D?) -> Place {
        var result = Place.fromSearchResult(
            name: place.name,
            category: place.category.map { $0.replacingOccurrences(of: "_", with: " ").capitalized } ?? "Place",
            coordinate: CLLocationCoordinate2D(latitude: place.lat, longitude: place.lng),
            address: place.address ?? "",
            distance: origin.map { place.distanceLabel(fromLat: $0.latitude, fromLng: $0.longitude) } ?? "",
            placeId: place.id,
            phone: place.phone,
            website: place.website
        )
        result.osmRef = place.osmRef
        result.openingHours = place.openingHours
        result.grade = OverallAccessibility(place.overallAccessibility)
        return result
    }

    nonisolated static func normalized(_ name: String) -> String {
        name.lowercased().filter { $0.isLetter || $0.isNumber }
    }
}

extension OverallAccessibility {
    /// The shared module decides the grade; this view-side enum only styles it.
    init(_ shared: Shared.OverallAccessibility) {
        switch shared {
        case .accessible: self = .accessible
        case .partiallyAccessible: self = .partiallyAccessible
        case .notAccessible: self = .notAccessible
        default: self = .noData
        }
    }
}
