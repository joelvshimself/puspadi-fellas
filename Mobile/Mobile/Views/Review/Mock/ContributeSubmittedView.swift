import SwiftUI

/// "Contribution Submitted" screen — matches the mockup's green checkmark
/// + "Review Submitted! Thank you for helping out!" + close-X + "Back to
/// Home". Distinct from the real `ReviewSubmittedView` (different copy/
/// layout) per the decision to build this flow's UI fresh.
struct ContributeSubmittedView: View {
    let onDone: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: onDone) {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.primary)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.green)

            Text("Review Submitted!")
                .font(.title2.bold())
                .padding(.top, 20)

            Text("Thank you for helping out!")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.top, 4)

            Spacer()

            Button(action: onDone) {
                Text("Back to Home")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContributeSubmittedView(onDone: {})
}
