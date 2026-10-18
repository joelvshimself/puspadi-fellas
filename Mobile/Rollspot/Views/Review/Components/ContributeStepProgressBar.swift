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
                    .fill(Color(.systemGray5))
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * fraction)
            }
        }
        .frame(height: 4)
        .padding(.vertical, 8)
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
