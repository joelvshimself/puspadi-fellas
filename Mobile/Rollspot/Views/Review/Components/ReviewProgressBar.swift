import SwiftUI

/// Slim step-progress indicator for the review wizard header.
struct ReviewProgressBar: View {
    let currentIndex: Int
    let totalSteps: Int

    private var progress: CGFloat {
        guard totalSteps > 0 else { return 0 }
        return CGFloat(currentIndex + 1) / CGFloat(totalSteps)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.secondarySystemBackground))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width * progress)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.25), value: progress)
    }
}

#Preview {
    ReviewProgressBar(currentIndex: 2, totalSteps: 8)
        .padding()
}
