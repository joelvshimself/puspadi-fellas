import MapKit
import SwiftUI

/// A compact, non-interactive locator map for the top of the place detail —
/// shows where the place is at a glance. Interaction is disabled so it doesn't
/// fight the surrounding ScrollView for drag gestures.
struct FacilityMapHeader: View {
    let coordinate: CLLocationCoordinate2D
    let name: String
    var height: CGFloat = 200

    private var region: MKCoordinateRegion {
        // Zoomed in close enough that MapKit renders building footprints (the
        // tan building outlines), and — for venues Apple has indoor-mapped —
        // the indoor floor plan. Most places only have footprints, not
        // unit-level indoor detail, since that data doesn't exist for them.
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.0016, longitudeDelta: 0.0016)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            Marker(name, coordinate: coordinate)
                .tint(.red)
        }
        .mapStyle(.standard(elevation: .flat, pointsOfInterest: .all, showsTraffic: false))
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
    }
}
