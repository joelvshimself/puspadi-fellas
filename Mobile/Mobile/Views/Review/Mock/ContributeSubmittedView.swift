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
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(.regularMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Spacer()

            // Filled green disc with a white check drawn on top, rather
            // than `checkmark.circle.fill` — the SF Symbol's ring is thin
            // and its glyph small, where the design is a solid circle with
            // a heavy white tick filling most of it.
            ZStack {
                Circle()
                    .fill(Color(red: 76 / 255, green: 187 / 255, blue: 88 / 255))
                    .frame(width: 132, height: 132)
                Image(systemName: "checkmark")
                    .font(.system(size: 62, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Review Submitted!".localized)
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 28)

            Text("Thank you for helping out!".localized)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            Button(action: onDone) {
                Text("Back to Home".localized)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background {
            // Blue hue bleeding down from the status bar, fading to the
            // page background well before the checkmark.
            LinearGradient(
                colors: [
                    Color(red: 148 / 255, green: 202 / 255, blue: 247 / 255),
                    Color(.systemBackground),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 260)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(Color(.systemBackground))
            .ignoresSafeArea()
        }
    }
}

#Preview {
    ContributeSubmittedView(onDone: {})
}
