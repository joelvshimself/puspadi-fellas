import Shared
import SwiftUI

struct AuthEmailFoundView: View {
    let email: String
    var onSuccess: () -> Void
    @Binding var path: [AuthRoute]
    @Binding var displayName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var emailText: String
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var passwordError: String?
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(
        email: String,
        onSuccess: @escaping () -> Void,
        path: Binding<[AuthRoute]>,
        displayName: Binding<String>
    ) {
        self.email = email
        self.onSuccess = onSuccess
        _path = path
        _displayName = displayName
        _emailText = State(initialValue: email)
    }

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                Text("Welcome to Rollspot".localized)
                    .font(.title.weight(.bold))

                Text("Sign in or create an account to save places and contribute to the community.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AuthFieldBox(isFocused: focusedField == .email) {
                        TextField("Email Address".localized, text: $emailText)
                            .textContentType(.emailAddress)
                            .keyboardType(.emailAddress)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .email)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password".localized)
                        .font(.caption)
                        .foregroundStyle(passwordError != nil ? AuthPalette.errorRed : .secondary)
                    AuthFieldBox(isFocused: focusedField == .password, isError: passwordError != nil) {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password".localized, text: $password)
                                } else {
                                    SecureField("Password".localized, text: $password)
                                }
                            }
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .password)

                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    if let passwordError {
                        Text(passwordError.localized)
                            .font(.caption)
                            .foregroundStyle(AuthPalette.errorRed)
                    }
                }

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: !password.isEmpty && AuthRules.shared.looksLikeEmail(value: emailText),
                    isLoading: isLoading
                ) {
                    Task { await submit() }
                }

                AuthSocialButtons(
                    onStep: { advanceAuth(to: $0, path: $path, displayName: $displayName, onDone: onSuccess) }
                )

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func submit() async {
        guard !isLoading else { return }
        passwordError = nil
        isLoading = true
        defer { isLoading = false }
        do {
            let step = try await auth.signIn(email: emailText, password: password)
            advanceAuth(to: step, path: $path, displayName: $displayName, onDone: onSuccess)
        } catch {
            passwordError = error.localizedDescription
        }
    }
}
