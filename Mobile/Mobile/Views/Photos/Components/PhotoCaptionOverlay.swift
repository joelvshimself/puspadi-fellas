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
