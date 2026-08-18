import SwiftUI

/// The "Toolbar - Top - iPhone" header shared by every screen in the photos
/// flow (node I518:16039;420:11200): a 44x44 Liquid Glass back button inset 22pt
/// from the leading edge, and a centred title — "Entrances" on the gallery,
/// "Add Photos" on the composer.
struct PhotoFlowHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Text(title)
                .font(.system(size: PhotoMetrics.titleSize, weight: .semibold))
                .foregroundStyle(.primary)

            HStack {
                backButton
                Spacer()
            }
        }
        .padding(.horizontal, PhotoMetrics.toolbarHorizontalPadding)
        .frame(height: PhotoMetrics.toolbarHeight)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(size: PhotoMetrics.backChevronSize, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: PhotoMetrics.backButtonSize, height: PhotoMetrics.backButtonSize)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircle()
        .accessibilityLabel("Back")
    }
}

private extension View {
    /// The mockup's toolbar button is a Liquid Glass circle. `glassEffect` only
    /// exists on iOS 26, so older systems fall back to a translucent material
    /// circle with the same hairline edge and soft shadow.
    @ViewBuilder
    func glassCircle() -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: .circle)
        } else {
            background(.regularMaterial, in: Circle())
                .overlay(
                    Circle().strokeBorder(Color.primary.opacity(0.06), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 5, y: 2)
        }
    }
}

#Preview {
    VStack(spacing: 0) {
        PhotoFlowHeader(title: "Entrances", onBack: {})
        PhotoFlowHeader(title: "Add Photos", onBack: {})
        Spacer()
    }
}
