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
    /// Low-quality stand-in shown, blurred, until the real image arrives.
    @State private var placeholder: UIImage?
    @State private var shownAttribution: String?
    @State private var finishedLoading = false

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
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
                // No spinner: an image should resolve into view, not sit behind
                // a progress wheel. Blurred thumbnail if we have one, otherwise
                // a soft neutral wash that the real photo fades over.
                ZStack {
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.tertiarySystemBackground),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    if let placeholder {
                        Image(uiImage: placeholder)
                            .resizable()
                            .scaledToFill()
                            .blur(radius: 12)
                            .clipped()
                    }
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
        .animation(.easeOut(duration: 0.35), value: image != nil)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        // Re-run when the enrich result resolves (so the Mapillary URL, if any,
        // is known before we decide on a fallback).
        .task(id: taskKey) {
            guard resolved else { return }
            let key = ImageStore.key(for: coordinate)

            // Already decoded: no network, and crucially no regenerating a
            // Look Around or map snapshot, which is what made revisits slow.
            if let cached = ImageStore.shared.image(for: key) {
                image = cached
                shownAttribution = attribution
                finishedLoading = true
                return
            }

            // Nothing full-size yet — show the low-quality thumbnail so there
            // is something on screen while the real one arrives.
            if image == nil {
                placeholder = ImageStore.shared.thumbnail(for: key)
            }

            await load()
            if let image { ImageStore.shared.store(image, for: key) }
        }
    }

    private var taskKey: String {
        "\(resolved)|\(remoteImageURL?.absoluteString ?? "")|\(coordinate.latitude),\(coordinate.longitude)"
    }

    private func load() async {
        // Deliberately not clearing `image` here: it may already hold the
        // thumbnail, and blanking it would put the spinner back.
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
        guard let data = try? await NetworkRetry.download(from: url) else { return nil }
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

#Preview {
    PlaceImageView(
        coordinate: CLLocationCoordinate2D(latitude: -8.72, longitude: 115.17),
        height: 180
    )
    .padding()
}
