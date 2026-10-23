import SwiftUI

/// "Contribution Submitted" (Figma): the thank-you illustration, "Review Submitted!",
/// "Thank you for helping out!" and a "Back to Home" button, on white.
struct ContributeSubmittedView: View {
    let onDone: () -> Void

    @State private var isHovering = false
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            // Design: the block sits a little above centre (3 : 2 space above vs below).
            Spacer(minLength: 0)
            Spacer(minLength: 0)
            Spacer(minLength: 0)

            Image("Thank You Asset")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 380)
                .offset(y: isHovering ? -6 : 4)
                .scaleEffect(appeared ? 1 : 0.94)
                .opacity(appeared ? 1 : 0)

            Text("Review Submitted!".localized)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(ContributePalette.text)
                // The illustration's glow has a soft margin; the design's title tucks into it.
                .padding(.top, -10)

            Text("Thank you for helping out!".localized)
                .font(.system(size: 16))
                .foregroundStyle(ContributePalette.secondaryText)
                .padding(.top, 8)

            Spacer(minLength: 0)
            Spacer(minLength: 0)

            Button(action: onDone) {
                Text("Back to Home".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(ContributePalette.blue, in: Capsule())
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 22)
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            // Entrance: a soft ease-out settle; then a slow float unless motion is reduced.
            withAnimation(.easeOut(duration: 0.35)) { appeared = true }
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                isHovering = true
            }
        }
    }
}

#Preview {
    ContributeSubmittedView(onDone: {})
}
