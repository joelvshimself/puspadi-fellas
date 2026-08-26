import SwiftUI

/// Renders a `FacilityPhoto` at whatever size the parent hands it, always
/// filling and clipping so mosaic tiles stay perfectly square regardless of the
/// photo's aspect ratio (Figma uses `object-cover` on every tile).
struct FacilityPhotoImage: View {
    let photo: FacilityPhoto
    var cornerRadius: CGFloat = PhotoMetrics.smallTileCornerRadius
    /// Mosaic tiles cover the square; the lightbox fits the whole photo.
    var fillsFrame: Bool = true

    @State private var remoteImage: UIImage?
    @State private var finishedLoadingRemote = false

    var body: some View {
        Color.clear
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        switch photo.source {
        case let .local(image):
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                .clipped()
        case let .asset(name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                .clipped()
        case let .remote(url):
            Group {
                if let remoteImage {
                    Image(uiImage: remoteImage)
                        .resizable()
                        .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
                        .clipped()
                } else if !finishedLoadingRemote {
                    placeholder(symbol: nil)
                } else {
                    placeholder(symbol: "photo")
                }
            }
            .task(id: url) {
                await loadRemote(from: url)
            }
        }
    }

    private func loadRemote(from url: URL) async {
        let key = ImageStore.key(for: url)
        // Already decoded — repaint, no network, no spinner.
        if let cached = ImageStore.shared.image(for: key) {
            remoteImage = cached
            finishedLoadingRemote = true
            return
        }
        // Only fall back to the spinner when there is genuinely nothing to
        // show. This used to clear `remoteImage` unconditionally, so every
        // reappearance blanked the tile and downloaded the photo again.
        if remoteImage == nil { finishedLoadingRemote = false }
        defer { finishedLoadingRemote = true }
        remoteImage = await ImageStore.shared.remoteImage(for: url)
    }

    private func placeholder(symbol: String?) -> some View {
        ZStack {
            Rectangle().fill(PhotoPalette.background1)
            if let symbol {
                Image(systemName: symbol)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}

#Preview {
    FacilityPhotoImage(photo: FacilityPhoto.samples.first ?? FacilityPhoto(source: .asset("SamplePlacePhoto")))
        .frame(width: 120, height: 120)
        .padding()
}
