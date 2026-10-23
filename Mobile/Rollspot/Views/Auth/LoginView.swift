import Shared
import SwiftUI

struct LoginView: View {
    var onSuccess: () -> Void
    var onCancel: () -> Void
    var onExploreMalls: () -> Void

    @State private var path: [AuthRoute]
    @State private var displayName: String = ""
    @State private var mobilityAids: Set<String>

    init(
        onSuccess: @escaping () -> Void,
        onCancel: @escaping () -> Void,
        onExploreMalls: @escaping () -> Void,
        initialPath: [AuthRoute] = [],
        initialMobilityAids: Set<String> = []
    ) {
        self.onSuccess = onSuccess
        self.onCancel = onCancel
        self.onExploreMalls = onExploreMalls
        _path = State(initialValue: initialPath)
        _mobilityAids = State(initialValue: initialMobilityAids)
    }

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
                    AuthEmailFoundView(
                        email: email,
                        onSuccess: onSuccess,
                        path: $path,
                        displayName: $displayName,
                        initialPassword: Self.reviewPassword,
                        initialError: Self.reviewPasswordError
                    )
                case .createPassword(let email):
                    AuthCreatePasswordView(email: email, path: $path, displayName: $displayName)
                case .verifyEmail(let email):
                    AuthVerifyEmailView(email: email, path: $path, onSuccess: onSuccess)
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

extension LoginView {
    #if DEBUG
    static var reviewPassword: String {
        [.emailFoundFilled, .emailFoundError].contains(DesignReview.current) ? "password123" : ""
    }
    static var reviewPasswordError: String? {
        DesignReview.current == .emailFoundError ? "Incorrect password. Try again." : nil
    }
    #else
    static let reviewPassword = ""
    static let reviewPasswordError: String? = nil
    #endif
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
                    AuthFieldBox(isFocused: emailFocused, isError: errorMessage != nil) {
                        TextField("Email Address".localized, text: $email)
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

                // Always looks active (design); an invalid email gets the shared inline error instead.
                AuthContinueButton(
                    title: "Continue".localized,
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
        guard !isCheckingEmail else { return }
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
