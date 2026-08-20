import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject private var auth: AuthSessionStore
    @State private var path: [AuthRoute] = []
    @State private var displayName: String = ""
    @State private var mobilityAids: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            AuthWelcomeView(
                onCancel: onCancel,
                onSuccess: onSuccess,
                path: $path
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .emailFound(let email):
                    AuthEmailFoundView(
                        email: email,
                        onSuccess: onSuccess,
                        onSocialSuccess: onSuccess
                    )
                case .createPassword(let email):
                    AuthCreatePasswordView(email: email, path: $path)
                case .verifyEmail(let email, let password):
                    AuthVerifyEmailView(email: email, password: password, path: $path)
                case .name:
                    AuthNameView(displayName: $displayName, path: $path)
                case .mobility:
                    AuthMobilityView(
                        mobilityAids: $mobilityAids,
                        displayName: displayName,
                        path: $path
                    )
                case .allSet:
                    AuthAllSetView(onExplore: onSuccess)
                }
            }
        }
        .onChange(of: auth.isSignedIn) { _, signedIn in
            // Apple sign-in from Welcome (empty stack) should close the gate.
            // Email signup stays signed-in while name/mobility continue on the stack.
            if signedIn, path.isEmpty {
                onSuccess()
            }
        }
    }
}

#Preview {
    LoginView(onSuccess: {}, onCancel: {})
        .environmentObject(AuthSessionStore())
        .environmentObject(LanguageManager.shared)
}

struct AuthWelcomeView: View {
    var onCancel: () -> Void
    var onSuccess: () -> Void
    @Binding var path: [AuthRoute]

    @EnvironmentObject private var auth: AuthSessionStore
    @FocusState private var emailFocused: Bool
    @State private var email = ""
    @State private var isChecking = false

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

                Text("Welcome to Roll-Spot".localized)
                    .font(.title.weight(.bold))
                    .foregroundStyle(AuthPalette.heading)

                Text("Sign in or create an account to save places and contribute to the community.".localized)
                    .font(.subheadline)
                    .foregroundStyle(AuthPalette.subtitle)

                AuthFieldBox(isFocused: emailFocused) {
                    TextField("Email Address".localized, text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($emailFocused)
                }

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: AuthPasswordRules.looksLikeEmail(email),
                    isLoading: isChecking
                ) {
                    Task { await continueWithEmail() }
                }

                AuthSocialButtons(onSuccess: onSuccess)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func continueWithEmail() async {
        isChecking = true
        defer { isChecking = false }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let exists = try await auth.emailRegistered(trimmed)
            if exists {
                path.append(.emailFound(trimmed))
            } else {
                path.append(.createPassword(trimmed))
            }
        } catch {
            // Hosted DB may not have email_registered yet — treat as a new account.
            path.append(.createPassword(trimmed))
        }
    }
}
