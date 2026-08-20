import SwiftUI

struct AuthEmailFoundView: View {
    let email: String
    var onSuccess: () -> Void
    var onSocialSuccess: () -> Void

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var emailText: String
    @State private var password = ""
    @State private var showPassword = false
    @State private var isLoading = false
    @State private var passwordError = false
    @FocusState private var focusedField: Field?

    private enum Field { case email, password }

    init(email: String, onSuccess: @escaping () -> Void, onSocialSuccess: @escaping () -> Void) {
        self.email = email
        self.onSuccess = onSuccess
        self.onSocialSuccess = onSocialSuccess
        _emailText = State(initialValue: email)
    }

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                Text("Welcome to Roll-Spot".localized)
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
                        .foregroundStyle(passwordError ? AuthPalette.errorRed : .secondary)
                    AuthFieldBox(isFocused: focusedField == .password, isError: passwordError) {
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
                    if passwordError {
                        Text("Incorrect password. Try again.".localized)
                            .font(.caption)
                            .foregroundStyle(AuthPalette.errorRed)
                    }
                }

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: !password.isEmpty && AuthPasswordRules.looksLikeEmail(emailText),
                    isLoading: isLoading
                ) {
                    Task { await submit() }
                }

                AuthSocialButtons(onSuccess: onSocialSuccess)

                Spacer()
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
    }

    private func submit() async {
        passwordError = false
        isLoading = true
        defer { isLoading = false }
        do {
            try await auth.signInWithEmail(
                email: emailText.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            onSuccess()
        } catch {
            passwordError = true
        }
    }
}
