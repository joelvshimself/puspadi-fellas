import MapKit
import SwiftUI

/// A photo-ish image for a place, sourced entirely from Apple/MapKit (free,
/// no per-call billing, no Google-style caching-ToS problem):
///   1. Look Around street-level imagery via MKLookAroundSnapshotter — often
///      shows the actual storefront/entrance, useful for accessibility.
///   2. If the location has no Look Around coverage, fall back to a plain
///      map snapshot (MKMapSnapshotter) so there's never a broken/empty box.
struct PlaceImageView: View {
    let coordinate: CLLocationCoordinate2D
    var height: CGFloat = 180

    @State private var image: UIImage?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if isLoading {
                ZStack {
                    Rectangle().fill(Color(.secondarySystemBackground))
                    ProgressView()
                }
            } else {
                // Both sources failed (rare) — neutral placeholder, no error.
                ZStack {
                    Rectangle().fill(Color(.secondarySystemBackground))
                    Image(systemName: "mappin.and.ellipse")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .task(id: "\(coordinate.latitude),\(coordinate.longitude)") {
            await load()
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        if let lookAround = await lookAroundSnapshot() {
            image = lookAround
            return
        }
        // No Look Around coverage here — fall back to a map snapshot.
        image = await mapSnapshot()
    }

    private func lookAroundSnapshot() async -> UIImage? {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        let options = MKLookAroundSnapshotter.Options()
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: options)
        return try? await snapshotter.snapshot.image
    }

    private func mapSnapshot() async -> UIImage? {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.003, longitudeDelta: 0.003)
        )
        options.pointOfInterestFilter = .includingAll
        let snapshotter = MKMapSnapshotter(options: options)
        return try? await snapshotter.start().image
    }
}
