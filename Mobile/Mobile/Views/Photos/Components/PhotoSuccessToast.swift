import SwiftUI

/// Green confirmation banner shown over the top of the gallery after photos are
/// submitted (node 572:7180). Dismissible by its own close button; the caller
/// also auto-hides it after `PhotoMetrics.toastDuration`.
struct PhotoSuccessToast: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: PhotoMetrics.toastSpacing) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 20))
                .foregroundStyle(PhotoPalette.toastForeground)

            Text(message)
                .font(.system(size: PhotoMetrics.toastTextSize))
                .tracking(-0.23)
                .foregroundStyle(PhotoPalette.toastForeground)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(PhotoPalette.toastForeground)
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(PhotoMetrics.toastPadding)
        .background(
            RoundedRectangle(cornerRadius: PhotoMetrics.toastCornerRadius, style: .continuous)
                .fill(PhotoPalette.toastBackground)
        )
        // drop-shadow 0 3.373 5.44 rgba(0,0,0,0.15) — CSS blur maps to radius blur/2.
        .shadow(color: .black.opacity(0.15), radius: 2.72, y: 3.373)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PhotoSuccessToast(message: "Your photos successfully added!", onDismiss: {})
        .padding(22)
}
