import SwiftUI

struct AuthNameView: View {
    let email: String
    let password: String
    @Binding var displayName: String
    @Binding var path: [AuthRoute]

    @Environment(\.dismiss) private var dismiss
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            AuthGradientBackground()

            VStack(alignment: .leading, spacing: 16) {
                AuthBackButton { dismiss() }
                    .padding(.top, 4)

                AuthProgressBar(progress: 0.33)
                    .padding(.vertical, 8)

                Text("What should we call you?".localized)
                    .font(.title.weight(.bold))

                AuthFieldBox(isFocused: nameFocused) {
                    TextField("Your name".localized, text: $displayName)
                        .textContentType(.name)
                        .focused($nameFocused)
                }

                Spacer()

                AuthContinueButton(
                    title: "Continue".localized,
                    enabled: !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ) {
                    let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
                    AuthDebug.log(
                        "Name continue email=\(email.isEmpty ? "empty" : email) "
                        + "passwordLen=\(password.count) name=\(trimmed)"
                    )
                    path.append(.mobility(email: email, password: password, displayName: trimmed))
                }
                .padding(.bottom, 12)
            }
            .padding(.horizontal, 24)
        }
        .navigationBarBackButtonHidden(true)
        .onAppear { nameFocused = true }
    }
}
