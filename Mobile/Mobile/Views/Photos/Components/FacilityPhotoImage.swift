import SwiftUI

/// Renders a `FacilityPhoto` at whatever size the parent hands it, always
/// filling and clipping so mosaic tiles stay perfectly square regardless of the
/// photo's aspect ratio (Figma uses `object-cover` on every tile).
struct FacilityPhotoImage: View {
    let photo: FacilityPhoto
    var cornerRadius: CGFloat = PhotoMetrics.smallTileCornerRadius

    var body: some View {
        // Sizing from a Color.clear base rather than from the image itself:
        // `scaledToFill` reports the overflowing size, which would otherwise
        // push the tile past the frame its parent handed it.
        Color.clear
            .overlay { content }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var content: some View {
        switch photo.source {
        case let .local(image):
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        case let .asset(name):
            Image(name)
                .resizable()
                .scaledToFill()
        case let .remote(url):
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .scaledToFill()
                case .failure:
                    placeholder(symbol: "photo")
                default:
                    placeholder(symbol: nil)
                }
            }
        }
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
