import SwiftUI

/// 4-Step Numbered Progress Header Bar for the Review Flow.
/// Steps: 1. Entrance | 2. Elevator | 3. Toilets | 4. Review
struct ContributeStepProgressBar: View {
    let currentStep: Int // 1-indexed (1 to 4)
    var subStepProgress: CGFloat = 0.35 // 0.0 to 1.0 progress within current step

    static let stepTitles = [
        "Entrance".localized,
        "Elevator".localized,
        "Toilets".localized,
        "Review".localized
    ]

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Background track connecting line with sub-progress gradient fill
                GeometryReader { geo in
                    let w = geo.size.width
                    let stepWidth = w / 4.0
                    let c1X = stepWidth * 0.5
                    let c2X = stepWidth * 1.5
                    let c3X = stepWidth * 2.5

                    let currentCenterX: CGFloat = switch currentStep {
                    case 1: c1X
                    case 2: c2X
                    case 3: c3X
                    default: w
                    }

                    let nextSegmentFill: CGFloat = if currentStep < 4 {
                        min(max(subStepProgress, 0.15), 1.0) * stepWidth
                    } else {
                        0
                    }

                    ZStack(alignment: .leading) {
                        // 1. Full width background gray line (edge to edge)
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(width: w, height: 2)

                        // 2. Solid accent blue line up to current step circle
                        Rectangle()
                            .fill(Color.accentColor)
                            .frame(width: currentCenterX, height: 2)

                        // 3. Gradient blue line extending towards next step circle
                        if currentStep < 4 && nextSegmentFill > 0 {
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.accentColor, Color.accentColor.opacity(0.15)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: nextSegmentFill, height: 2)
                                .offset(x: currentCenterX)
                        }
                    }
                    .frame(width: w, height: geo.size.height, alignment: .leading)
                }

                // 4 Numbered step circles
                HStack(spacing: 0) {
                    ForEach(1...4, id: \.self) { step in
                        let isCurrent = step == currentStep
                        let isCompleted = step < currentStep

                        ZStack {
                            Circle()
                                .fill(isCurrent || isCompleted ? Color.accentColor : Color(.systemGray4))
                                .frame(width: 28, height: 28)

                            Text("\(step)")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundStyle(isCurrent || isCompleted ? .white : Color(.secondaryLabel))
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: 28)

            // Step labels below circles
            HStack(spacing: 0) {
                ForEach(1...4, id: \.self) { step in
                    let isCurrent = step == currentStep
                    let isCompleted = step < currentStep
                    let idx = step - 1
                    let title = idx >= 0 && idx < Self.stepTitles.count ? Self.stepTitles[idx] : ""

                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(isCurrent ? Color.primary : (isCompleted ? Color.primary : Color(.systemGray)))
                        .frame(maxWidth: .infinity)
                }
            }
        }
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
}
