import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject private var auth: AuthSessionStore
    @State private var path: [AuthRoute] = []
    @State private var signupEmail = ""
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
                signupEmail: $signupEmail,
                signupPassword: $signupPassword,
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
                        path: $path
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
                        path: $path
                    )
                case .allSet:
                    AuthAllSetView(onExplore: onSuccess)
                }
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
    @Binding var signupEmail: String
    @Binding var signupPassword: String
    @Binding var pendingAppleSignIn: PendingAppleSignIn?
    @Binding var displayName: String
    @Binding var mobilityAids: Set<String>

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

                AuthSocialButtons(
                    onSuccess: onSuccess,
                    onNeedsOnboarding: beginAppleOnboarding,
                    onDeferAppleSignIn: deferAppleSignIn
                )

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
                signupEmail = trimmed
                signupPassword = ""
                pendingAppleSignIn = nil
                displayName = ""
                mobilityAids = []
                AuthDebug.log("Welcome new email → createPassword email=\(trimmed)")
                path.append(.createPassword(trimmed))
            }
        } catch {
            // Hosted DB may not have email_registered yet — treat as a new account.
            signupEmail = trimmed
            signupPassword = ""
            pendingAppleSignIn = nil
            displayName = ""
            mobilityAids = []
            AuthDebug.log("Welcome email_registered failed, treating as new email=\(trimmed)")
            path.append(.createPassword(trimmed))
        }
    }

    private func beginAppleOnboarding(suggestedName: String?) {
        displayName = suggestedName ?? ""
        mobilityAids = []
        AuthDebug.log(
            "beginAppleOnboarding name=\(displayName) pendingApple=\(pendingAppleSignIn != nil) "
            + "signupPasswordLen=\(signupPassword.count)"
        )
        path.append(.name(email: "", password: ""))
    }

    private func deferAppleSignIn(_ pending: PendingAppleSignIn, suggestedName: String?) {
        pendingAppleSignIn = pending
        beginAppleOnboarding(suggestedName: suggestedName)
    }
}
