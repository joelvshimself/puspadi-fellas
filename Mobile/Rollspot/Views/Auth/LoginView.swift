import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void
    var onExploreMalls: () -> Void

    @State private var path: [AuthRoute] = []
    @State private var signupPassword = ""
    @State private var pendingAppleSignIn: PendingAppleSignIn?
    @State private var displayName: String = ""
    @State private var mobilityAids: Set<String> = []

    var body: some View {
        NavigationStack(path: $path) {
            AuthWelcomeView(
                onCancel: onCancel,
                onSuccess: onSuccess,
                path: $path,
                pendingAppleSignIn: $pendingAppleSignIn,
                displayName: $displayName,
                mobilityAids: $mobilityAids
            )
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden(true)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .emailFound(let email):
                    AuthEmailFoundView(
                        email: email,
                        onSuccess: onSuccess,
                        path: $path,
                        pendingAppleSignIn: $pendingAppleSignIn,
                        displayName: $displayName,
                        mobilityAids: $mobilityAids
                    )
                case .createPassword(let email):
                    AuthCreatePasswordView(
                        email: email,
                        signupPassword: $signupPassword,
                        path: $path
                    )
                case .verifyEmail(let email, let password, let displayName, let mobilityAids):
                    AuthVerifyEmailView(
                        email: email,
                        password: password,
                        displayName: displayName,
                        mobilityAids: mobilityAids,
                        path: $path,
                        onSuccess: onSuccess
                    )
                case .name(let email, let password):
                    AuthNameView(
                        email: email,
                        password: password,
                        displayName: $displayName,
                        path: $path
                    )
                case .mobility(let email, let password, let displayName):
                    AuthMobilityView(
                        email: email,
                        password: password,
                        pendingAppleSignIn: $pendingAppleSignIn,
                        mobilityAids: $mobilityAids,
                        displayName: displayName,
                        path: $path,
                        onSuccess: onSuccess
                    )
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
    @Binding var pendingAppleSignIn: PendingAppleSignIn?
    @Binding var displayName: String
    @Binding var mobilityAids: Set<String>
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
                    enabled: AuthPasswordRules.looksLikeEmail(email),
                    isLoading: isCheckingEmail
                ) {
                    Task { await continueWithEmail() }
                }

                AuthSocialButtons(
                    onSuccess: onSuccess,
                    onNeedsOnboarding: beginSocialOnboarding,
                    onDeferAppleSignIn: deferAppleSignIn,
                    showsOrLabel: true
                )

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func continueWithEmail() async {
        guard !isCheckingEmail, AuthPasswordRules.looksLikeEmail(email) else { return }
        isCheckingEmail = true
        errorMessage = nil
        defer { isCheckingEmail = false }
        let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        do {
            path.append(try await auth.emailRegistered(normalized) ? .emailFound(normalized) : .createPassword(normalized))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginSocialOnboarding(suggestedName: String?) {
        displayName = suggestedName ?? ""
        mobilityAids = []
        AuthDebug.log(
            "beginAppleOnboarding name=\(displayName) pendingApple=\(pendingAppleSignIn != nil)"
        )
        path.append(.name(email: "", password: ""))
    }

    private func deferAppleSignIn(_ pending: PendingAppleSignIn, suggestedName: String?) {
        pendingAppleSignIn = pending
        beginSocialOnboarding(suggestedName: suggestedName)
    }
}
