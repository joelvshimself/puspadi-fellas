import Shared
import SwiftUI

/// "Your contribution is waiting · <place> · In progress" (Figma Home "Continue Survey").
/// Used as the floating banner on Home and as the first row of Profile → Reviews.
struct ContinueSurveyBanner: View {
    let contribution: WaitingContribution
    var compact = false
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: compact ? 8 : 12) {
                ZStack {
                    Circle().fill(AuthPalette.brandBlue)
                    // The design's dotted ring: a survey that's part-way done.
                    Circle()
                        .strokeBorder(.white, style: StrokeStyle(lineWidth: compact ? 1.5 : 2, dash: [2.5, 2.5]))
                        .padding(compact ? 4 : 6)
                }
                .frame(width: compact ? 22 : 34, height: compact ? 22 : 34)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Your contribution is waiting".localized)
                        .font(.system(size: compact ? 12 : 15, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text("\(contribution.placeName) · \("In progress".localized)")
                        .font(.system(size: compact ? 10 : 12))
                        .foregroundStyle(.secondary)
                }
                .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: compact ? 10 : 13, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, compact ? 10 : 14)
            .padding(.vertical, compact ? 8 : 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Continue your review".localized)
    }
}
