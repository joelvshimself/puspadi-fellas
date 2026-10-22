import SwiftUI

/// Location note screen for Accessible Toilets: "Where is the accessible toilet? (Optional)"
struct ContributeToiletLocationStepView: View {
    var navTitle: String = "Accessible Toilets"
    var question: String = "Where is the accessible toilet?"
    var illustrationAssetName: String? = nil
    var stepNumber: Int = 3
    var subStepProgress: CGFloat = 0.85
    @Binding var locationText: String
    let onBack: () -> Void
    let onContinue: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if let illustrationAssetName {
                            ContributeIllustration(name: illustrationAssetName)
                        } else {
                            ContributeFacilityIllustration(kind: .toilet)
                        }
                    }
                    .padding(.top, 26)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(question.localized)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ContributePalette.text)
                        Text("(Optional)".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(ContributePalette.optionalText)
                    }
                    .padding(.top, 40)

                    ZStack(alignment: .topLeading) {
                        if locationText.isEmpty {
                            Text("Describe what's around ...".localized)
                                .font(.system(size: 15))
                                .foregroundStyle(ContributePalette.placeholder)
                                .padding(.horizontal, 15)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                        TextField("", text: $locationText, axis: .vertical)
                            .focused($isFocused)
                            .font(.system(size: 15))
                            .foregroundStyle(ContributePalette.text)
                            .lineLimit(1...6)
                            .padding(.horizontal, 15)
                            .padding(.vertical, 16)
                    }
                    .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
                    .background(ContributePalette.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(ContributePalette.blue.opacity(isFocused ? 0.5 : 0), lineWidth: 2)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { isFocused = true }
                    .animation(.easeOut(duration: 0.15), value: isFocused)
                    .padding(.top, 16)
                }
                .padding(.horizontal, 20)
            }
            .scrollDismissesKeyboard(.interactively)

            ContributeContinueButton(isEnabled: true, action: onContinue)
        }
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContributeToiletLocationStepView(
        locationText: .constant(""),
        onBack: {},
        onContinue: {}
    )
}
