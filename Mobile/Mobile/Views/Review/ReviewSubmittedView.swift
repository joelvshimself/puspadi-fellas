import SwiftUI

/// Final placeholder confirmation screen — no grade/score shown here, that
/// lives on PlaceDetailView's existing Accessibility Grade card, computed
/// later by the backend from this submission.
struct ReviewSubmittedView: View {
    let placeName: String
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 8) {
                Text("Thank You!")
                    .font(.title2.bold())
                Text("Your review helps make \(placeName) more accessible for everyone.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onDone) {
                Text("Done")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ReviewSubmittedView(placeName: "Central Library", onDone: {})
}
