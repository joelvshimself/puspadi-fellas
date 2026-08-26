import SwiftUI

/// Location note screen for Accessible Toilets: "Where is the accessible toilet? (Optional)"
struct ContributeToiletLocationStepView: View {
    @Binding var locationText: String
    let onBack: () -> Void
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PhotoFlowHeader(title: "Accessible Toilets".localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: 3, subStepProgress: 0.85)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ContributeFacilityIllustration(kind: .toilet)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Where is the accessible toilet?".localized)
                            .font(.title2.bold())
                        Text("(Optional)".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $locationText)
                            .focused($isFocused)
                            .font(.system(size: 16))
                            .frame(minHeight: 140)
                            .scrollContentBackground(.hidden)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5)
                            }

                        if locationText.isEmpty {
                            Text("Describe what's around ...".localized)
                                .font(.system(size: 16))
                                .foregroundStyle(Color(.placeholderText))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                                .allowsHitTesting(false)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: true, action: onContinue)
        }
        .background(Color(.systemBackground))
        .onTapGesture {
            isFocused = false
        }
    }
}

#Preview {
    ContributeToiletLocationStepView(
        locationText: .constant(""),
        onBack: {},
        onContinue: {}
    )
}
