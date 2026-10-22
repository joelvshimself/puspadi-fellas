import Shared
import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void
    var onExploreMalls: () -> Void

    @State private var path: [AuthRoute] = []
    @State private var displayName: String = ""
    @State private var mobilityAids: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            AuthWelcomeView(
                onCancel: onCancel,
                onSuccess: onSuccess,
                path: $path,
                displayName: $displayName
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .emailFound(let email):
                    AuthEmailFoundView(email: email, onSuccess: onSuccess, path: $path, displayName: $displayName)
                case .createPassword(let email):
                    AuthCreatePasswordView(email: email, path: $path, displayName: $displayName)
                case .verifyEmail(let email):
                    AuthVerifyEmailView(email: email, onSuccess: onSuccess)
                case .name:
                    AuthNameView(displayName: $displayName, path: $path)
                case .mobility:
                    AuthMobilityView(mobilityAids: $mobilityAids, path: $path, onSuccess: onSuccess)
                case .allSet:
                    AuthAllSetView(onExplore: onExploreMalls)
                }
            }
        }
    }
}

#Preview {
    LoginView(onSuccess: {}, onCancel: {}, onExploreMalls: {})
        .environmentObject(AuthSessionStore())
        .environmentObject(LanguageManager.shared)
}

struct AuthWelcomeView: View {
    var onCancel: () -> Void
    var onSuccess: () -> Void
    @Binding var path: [AuthRoute]
    @Binding var displayName: String
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var email = ""
    @State private var isCheckingEmail = false
    @State private var errorMessage: String?
    @FocusState private var emailFocused: Bool

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Spacer()
                    Button("Not now".localized, action: onCancel)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)

                Text("Welcome to Rollspot".localized)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AuthPalette.heading)

                Text("Sign in or create an account to save places and contribute to the community.".localized)
                    .font(.subheadline)
                    .foregroundStyle(AuthPalette.subtitle)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AuthFieldBox(isFocused: emailFocused, isError: errorMessage != nil) {
                        TextField("you@example.com", text: $email)
                            .keyboardType(.emailAddress)
                            .textContentType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($emailFocused)
                            .submitLabel(.continue)
                            .onSubmit { Task { await continueWithEmail() } }
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(AuthPalette.errorRed)
                    }
                }

                AuthContinueButton(
                    title: "Continue with Email".localized,
                    enabled: AuthRules.shared.looksLikeEmail(value: email),
                    isLoading: isCheckingEmail
                ) {
                    Task { await continueWithEmail() }
                }

                AuthSocialButtons(
                    onStep: { advanceAuth(to: $0, path: $path, displayName: $displayName, onDone: onSuccess) },
                    showsOrLabel: true
                )

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func continueWithEmail() async {
        guard !isCheckingEmail, AuthRules.shared.looksLikeEmail(value: email) else { return }
        isCheckingEmail = true
        errorMessage = nil
        defer { isCheckingEmail = false }
        do {
            let step = try await auth.continueWithEmail(email)
            advanceAuth(to: step, path: $path, displayName: $displayName, onDone: onSuccess)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
