import SwiftUI

/// Final placeholder confirmation screen — no grade/score shown here, that
/// lives on PlaceDetailView's existing Accessibility Grade card, computed
/// later by the backend from this submission.
struct ReviewSubmittedView: View {
    var placeName: String = ""
    let onDone: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack {
            Spacer()

            Image("Thank You Asset")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .scaleEffect(1.08)
                .offset(y: isHovering ? -8 : 6)
                .frame(height: 245)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                        isHovering = true
                    }
                }

            Text("Review Submitted!".localized)
                .font(.system(size: 26, weight: .bold))
                .padding(.top, 24)

            Text("Thank you for helping out!".localized)
                .font(.system(size: 16))
                .foregroundStyle(.secondary)
                .padding(.top, 8)

            Spacer()

            Button(action: onDone) {
                Text("Okey".localized)
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
    ReviewSubmittedView(placeName: "Central Library", onDone: {})
}
