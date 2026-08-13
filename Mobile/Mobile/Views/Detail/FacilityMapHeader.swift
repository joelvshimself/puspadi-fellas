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
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.004, longitudeDelta: 0.004)
        )
    }

    var body: some View {
        Map(initialPosition: .region(region), interactionModes: []) {
            Marker(name, coordinate: coordinate)
                .tint(.red)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .allowsHitTesting(false)
    }
}
