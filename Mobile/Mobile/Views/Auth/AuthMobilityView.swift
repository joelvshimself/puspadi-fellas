import SwiftUI

struct AuthMobilityView: View {
    let email: String
    let password: String
    @Binding var pendingAppleSignIn: PendingAppleSignIn?
    @Binding var mobilityAids: Set<String>
    var displayName: String
    @Binding var path: [AuthRoute]

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore
    @State private var isSaving = false
    @State private var errorMessage: String?

    private let options = [
        "Wheelchair",
        "Crutches",
        "Walking Aid",
        "No mobility aid",
        "Other"
    ]

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                AuthProgressBar(progress: 0.66)
                    .padding(.vertical, 8)

                Text("How do you usually get around?".localized)
                    .font(.title.weight(.bold))

                Text("Select all that apply".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        let selected = mobilityAids.contains(option)
                        Button {
                            if selected {
                                mobilityAids.remove(option)
                            } else {
                                mobilityAids.insert(option)
                            }
                        } label: {
                            HStack {
                                Text(option.localized)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(AuthPalette.brandBlue)
                                        .font(.title3)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(AuthPalette.fieldFill)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(selected ? AuthPalette.brandBlue : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(AuthPalette.errorRed)
                }

                Spacer()

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: !mobilityAids.isEmpty,
                    isLoading: isSaving
                ) {
                    Task { await saveAndContinue() }
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            AuthDebug.log(
                "Mobility onAppear email=\(email.isEmpty ? "empty" : email) "
                + "passwordLen=\(password.count) "
                + "pendingApple=\(pendingAppleSignIn != nil) "
                + "isSignedIn=\(auth.isSignedIn) "
                + "userId=\(auth.userId?.uuidString ?? "nil") "
                + "name=\(displayName) aids=\(mobilityAids.sorted())"
            )
        }
    }

    private func saveAndContinue() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let aids = mobilityAids.sorted()
        AuthDebug.log(
            "Mobility continue email=\(email.isEmpty ? "empty" : email) "
            + "passwordLen=\(password.count) "
            + "pendingApple=\(pendingAppleSignIn != nil) "
            + "isSignedIn=\(auth.isSignedIn) "
            + "name=\(trimmedName) aids=\(aids)"
        )
        do {
            if let pendingAppleSignIn {
                AuthDebug.log("Mobility branch: completeAppleSignup")
                try await auth.completeAppleSignup(
                    pending: pendingAppleSignIn,
                    displayName: trimmedName,
                    mobilityAids: aids
                )
                AuthDebug.log("Mobility completeAppleSignup success → allSet")
                path.append(.allSet)
            } else if !password.isEmpty {
                AuthDebug.log("Mobility branch: registerEmailAccount")
                switch try await auth.registerEmailAccount(
                    email: email,
                    password: password,
                    displayName: trimmedName,
                    mobilityAids: aids
                ) {
                case .ready:
                    AuthDebug.log("Mobility registerEmailAccount → allSet")
                    path.append(.allSet)
                case .needsEmailConfirmation:
                    AuthDebug.log("Mobility registerEmailAccount → verifyEmail")
                    path.append(
                        .verifyEmail(
                            email: email,
                            password: password,
                            displayName: trimmedName,
                            mobilityAids: aids
                        )
                    )
                }
            } else if auth.isSignedIn {
                AuthDebug.log("Mobility branch: updateOnboardingProfile (already signed in)")
                try await auth.updateOnboardingProfile(
                    displayName: trimmedName,
                    mobilityAids: aids
                )
                AuthDebug.log("Mobility updateOnboardingProfile success → allSet")
                path.append(.allSet)
            } else {
                AuthDebug.log(
                    "Mobility branch: NO CREDENTIALS — password empty, not signed in, no pending Apple"
                )
                errorMessage = "Something went wrong. Try again.".localized
            }
        } catch {
            AuthDebug.log("Mobility error: \(type(of: error)) \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }
    }
}
