import SwiftUI

/// Bottom gradient + caption text overlaid on a photo tile or lightbox frame.
struct PhotoCaptionOverlay: View {
    let caption: String
    var fontSize: CGFloat = 11
    var lineLimit: Int = 2
    var horizontalPadding: CGFloat = 8
    var verticalPadding: CGFloat = 6

    var body: some View {
        Text(caption)
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.7)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
    }
}

/// Small white circle indicating a photo has a caption — used on thumbnails
/// instead of showing caption text inline.
struct PhotoCaptionBadge: View {
    var size: CGFloat = 28
    var iconSize: CGFloat = 13

    var body: some View {
        Image(systemName: "text.bubble.fill")
            .font(.system(size: iconSize, weight: .semibold))
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .background(Color.white, in: Circle())
            .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
    }
}

/// Full-width footer bar for the photo lightbox — bubble icon + caption text.
struct PhotoCaptionFooterBar: View {
    let caption: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "text.bubble.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Color.white.opacity(0.22), in: Circle())

            Text(caption)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.black)
    }
}
