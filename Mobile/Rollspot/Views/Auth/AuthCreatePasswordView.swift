import Shared
import SwiftUI

struct AuthCreatePasswordView: View {
    let email: String
    @Binding var path: [AuthRoute]
    @Binding var displayName: String

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var showConfirm = false
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirm }

    private var passwordValid: Bool { AuthRules.shared.isValidPassword(password: password) }
    private var canContinue: Bool { passwordValid && password == confirm && !confirm.isEmpty }

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                Text("Create a password".localized)
                    .font(.title.weight(.bold))

                VStack(alignment: .leading, spacing: 6) {
                    Text("Email".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AuthFieldBox {
                        Text(email)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Password".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AuthFieldBox(isFocused: focusedField == .password) {
                        HStack {
                            Group {
                                if showPassword {
                                    TextField("Password".localized, text: $password)
                                } else {
                                    SecureField("Password".localized, text: $password)
                                }
                            }
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .password)
                            Button { showPassword.toggle() } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(AuthRules.shared.PASSWORD_HINT.localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Confirm Password".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    AuthFieldBox(isFocused: focusedField == .confirm) {
                        HStack {
                            Group {
                                if showConfirm {
                                    TextField("Confirm Password".localized, text: $confirm)
                                } else {
                                    SecureField("Confirm Password".localized, text: $confirm)
                                }
                            }
                            .textContentType(.newPassword)
                            .textInputAutocapitalization(.never)
                            .focused($focusedField, equals: .confirm)
                            Button { showConfirm.toggle() } label: {
                                Image(systemName: showConfirm ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Spacer()

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: canContinue
                ) {
                    if let step = try? auth.choosePassword(password) {
                        advanceAuth(to: step, path: $path, displayName: $displayName, onDone: {})
                    }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
    }
}
