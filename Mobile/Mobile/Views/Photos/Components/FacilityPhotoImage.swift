import SwiftUI

/// Renders a `FacilityPhoto` at whatever size the parent hands it, always
/// filling and clipping so mosaic tiles stay perfectly square regardless of the
/// photo's aspect ratio (Figma uses `object-cover` on every tile).
struct FacilityPhotoImage: View {
    let photo: FacilityPhoto
    var cornerRadius: CGFloat = PhotoMetrics.smallTileCornerRadius
    /// Mosaic tiles cover the square; the lightbox fits the whole photo.
    var fillsFrame: Bool = true

    var body: some View {
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
                .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
        case let .asset(name):
            Image(name)
                .resizable()
                .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
        case let .remote(url):
            AsyncImage(url: url) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: fillsFrame ? .fill : .fit)
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
