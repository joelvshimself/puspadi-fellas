import SwiftUI

struct AuthMobilityView: View {
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
    }

    private func saveAndContinue() async {
        errorMessage = nil
        isSaving = true
        defer { isSaving = false }
        do {
            try await auth.updateOnboardingProfile(
                displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                mobilityAids: mobilityAids.sorted()
            )
            path.append(.allSet)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
