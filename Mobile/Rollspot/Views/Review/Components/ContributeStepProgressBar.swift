import SwiftUI

/// Single capsule for the contribute flow. Fill advances by section
/// (Entrance, Elevator, Toilet, Review) and within the current section.
struct ContributeStepProgressBar: View {
    let currentStep: Int // 1-indexed (1 to 4)
    var subStepProgress: CGFloat = 0.35 // 0.0 to 1.0 progress within current step

    private var fraction: CGFloat {
        let within = min(max(subStepProgress, 0), 1)
        let raw = (CGFloat(currentStep - 1) + within) / 4
        return min(max(raw, 0.05), 1)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ContributePalette.progressTrack)
                Capsule()
                    .fill(ContributePalette.progressFill)
                    .frame(width: geo.size.width * fraction)
                    .animation(.easeOut(duration: 0.25), value: fraction)
            }
        }
        .frame(height: 4)
        // Design: 20pt side insets, just under the status bar, above the back button.
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }
}

#Preview {
    VStack(spacing: 20) {
        ContributeStepProgressBar(currentStep: 1)
        ContributeStepProgressBar(currentStep: 2)
        ContributeStepProgressBar(currentStep: 3)
        ContributeStepProgressBar(currentStep: 4)
    }
    .padding()
}
