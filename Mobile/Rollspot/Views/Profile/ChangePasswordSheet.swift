import Shared
import SwiftUI

struct ChangePasswordSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var currentPassword = ""
    @State private var password = ""
    @State private var confirm = ""
    @State private var showPassword = false
    @State private var showCurrentPassword = false
    @State private var showConfirm = false
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didSucceed = false
    @FocusState private var focusedField: Field?

    private enum Field { case currentPassword, password, confirm }

    private var passwordValid: Bool { AuthRules.shared.isValidPassword(password: password) }
    private var canSave: Bool { !currentPassword.isEmpty && passwordValid && password == confirm && !confirm.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Change Password".localized)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 6) {
                Text("Current Password".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AuthFieldBox(isFocused: focusedField == .currentPassword) {
                    HStack {
                        Group {
                            if showCurrentPassword {
                                TextField("Current Password".localized, text: $currentPassword)
                            } else {
                                SecureField("Current Password".localized, text: $currentPassword)
                            }
                        }
                        .textContentType(.password)
                        .textInputAutocapitalization(.never)
                        .focused($focusedField, equals: .currentPassword)

                        Button { showCurrentPassword.toggle() } label: {
                            Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
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
                Text("Use at least 8 characters, including a number and a special character.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Confirm Password".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                AuthFieldBox(isFocused: focusedField == .confirm, isError: !confirm.isEmpty && confirm != password) {
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

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AuthPalette.errorRed)
            }

            if didSucceed {
                Text("Password updated.".localized)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color.green)
            }

            Spacer(minLength: 0)

            AuthContinueButton(
                title: "Save".localized,
                enabled: canSave,
                isLoading: isSaving
            ) {
                Task { await save() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func save() async {
        guard !isSaving, canSave else { return }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await auth.updatePassword(currentPassword: currentPassword, newPassword: password)
            didSucceed = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    ChangePasswordSheet()
        .environmentObject(AuthSessionStore())
        .environmentObject(LanguageManager.shared)
}
