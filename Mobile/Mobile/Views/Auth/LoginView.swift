import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void

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
    @Binding var pendingAppleSignIn: PendingAppleSignIn?
    @Binding var displayName: String
    @Binding var mobilityAids: Set<String>

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

                AuthSocialButtons(
                    onSuccess: onSuccess,
                    onNeedsOnboarding: beginAppleOnboarding,
                    onDeferAppleSignIn: deferAppleSignIn,
                    showsOrLabel: false
                )

                Spacer()
            }
            .padding(.horizontal, 24)
        }
    }

    private func beginAppleOnboarding(suggestedName: String?) {
        displayName = suggestedName ?? ""
        mobilityAids = []
        AuthDebug.log(
            "beginAppleOnboarding name=\(displayName) pendingApple=\(pendingAppleSignIn != nil)"
        )
        path.append(.name(email: "", password: ""))
    }

    private func deferAppleSignIn(_ pending: PendingAppleSignIn, suggestedName: String?) {
        pendingAppleSignIn = pending
        beginAppleOnboarding(suggestedName: suggestedName)
    }
}
