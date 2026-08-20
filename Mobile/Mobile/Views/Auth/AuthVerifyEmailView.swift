import SwiftUI

struct AuthVerifyEmailView: View {
    let email: String
    let password: String
    @Binding var path: [AuthRoute]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var isLoading = false
    @State private var isResending = false
    @State private var errorMessage: String?
    @State private var resentHint: String?

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                AuthProgressBar(progress: 0.18)
                    .padding(.vertical, 8)

                Text("Confirm your email".localized)
                    .font(.title.weight(.bold))

                (Text("We sent a confirmation link to".localized)
                    .foregroundStyle(.secondary)
                    + Text(" \(email)")
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary))
                    .font(.subheadline)

                Text("Open that email and tap the link, then come back here.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AuthPalette.errorRed)
                }

                if let resentHint {
                    Text(resentHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await resend() }
                } label: {
                    HStack(spacing: 6) {
                        if isResending { ProgressView() }
                        Text("Resend email".localized)
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundStyle(AuthPalette.brandBlue)
                }
                .disabled(isResending)
                .buttonStyle(.plain)

                Spacer()

                AuthContinueButton(
                    title: "I've confirmed".localized,
                    isLoading: isLoading
                ) {
                    Task { await continueAfterConfirm() }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func continueAfterConfirm() async {
        errorMessage = nil
        resentHint = nil
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signInAfterEmailConfirmed(email: email, password: password)
            path.append(.name)
        } catch {
            errorMessage = "Please tap the link in your email first, then try again.".localized
        }
    }

    private func resend() async {
        errorMessage = nil
        isResending = true
        defer { isResending = false }
        do {
            try await auth.resendConfirmationEmail(email: email)
            resentHint = "A new confirmation email was sent.".localized
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
