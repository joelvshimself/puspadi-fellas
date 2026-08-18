import MapKit
import SwiftUI

/// A photo for a place, tried in order of usefulness/quality:
///   1. Mapillary — open, CC BY-SA street-level photo cached server-side in
///      Supabase Storage (real ground-level image, often shows the entrance).
///   2. Look Around — Apple street-level imagery via MKLookAroundSnapshotter,
///      where Mapillary has no coverage.
///   3. Map snapshot (MKMapSnapshotter) — so there's never a broken box.
/// All free, no per-call billing. Only the Mapillary image needs attribution
/// (shown as an overlay), which its license requires.
struct PlaceImageView: View {
    let coordinate: CLLocationCoordinate2D
    /// Cached Mapillary Storage URL from the enrich response; nil if none.
    var remoteImageURL: URL?
    var attribution: String?
    /// True once the enrich call has returned, so we know whether a Mapillary
    /// URL exists before deciding to fall back. Avoids a fallback flash.
    var resolved: Bool = true
    var height: CGFloat = 180
    /// 0 for a full-bleed hero; the default rounds the inline card.
    var cornerRadius: CGFloat = 16

    @State private var image: UIImage?
    @State private var shownAttribution: String?
    @State private var finishedLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .overlay(alignment: .bottomLeading) {
                        if let shownAttribution {
                            Text(shownAttribution)
                                .font(.caption2)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.45), in: Capsule())
                                .padding(8)
                        }
                    }
            } else if !finishedLoading {
                ZStack {
                    Rectangle().fill(Color(.secondarySystemBackground))
                    ProgressView()
                }
            } else {
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
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Re-run when the enrich result resolves (so the Mapillary URL, if any,
        // is known before we decide on a fallback).
        .task(id: taskKey) {
            guard resolved else { return }
            await load()
        }
    }

    private var taskKey: String {
        "\(resolved)|\(remoteImageURL?.absoluteString ?? "")|\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func load() async {
        finishedLoading = false

        // 1. Mapillary (cached, real street-level photo).
        if let remoteImageURL, let downloaded = await downloadImage(remoteImageURL) {
            image = downloaded
            shownAttribution = attribution
            finishedLoading = true
            return
        }
        // 2. Apple Look Around.
        if let lookAround = await lookAroundSnapshot() {
            image = lookAround
            shownAttribution = nil
            finishedLoading = true
            return
        }
        // 3. Plain map snapshot.
        image = await mapSnapshot()
        shownAttribution = nil
        finishedLoading = true
    }

    private func downloadImage(_ url: URL) async -> UIImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return UIImage(data: data)
    }

    private func lookAroundSnapshot() async -> UIImage? {
        let request = MKLookAroundSceneRequest(coordinate: coordinate)
        guard let scene = try? await request.scene else { return nil }
        let snapshotter = MKLookAroundSnapshotter(scene: scene, options: MKLookAroundSnapshotter.Options())
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
