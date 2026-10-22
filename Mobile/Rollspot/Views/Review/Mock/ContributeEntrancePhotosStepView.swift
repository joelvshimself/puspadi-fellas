import SwiftUI

/// Optional entrance photo before the accessible-entrances location picker.
struct ContributeEntrancePhotosStepView: View {
    var navTitle: String = "Entrances"
    var illustrationAssetName: String = "Lobby Asset"
    var stepNumber: Int = 1
    let progress: (current: Int, total: Int)
    var subStepProgress: CGFloat = 0.35
    @Binding var note: ReviewNoteDraft
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
            PhotoFlowHeader(title: navTitle.localized, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ContributeIllustration(name: illustrationAssetName, height: 120)
                        .padding(.top, 30)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Take or upload a photo".localized)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ContributePalette.text)
                        Text("(Optional)".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(ContributePalette.optionalText)
                    }
                    .padding(.top, 50)

                    ContributePhotoStrip(note: $note, style: .box)
                        .padding(.top, 30)
                }
                .padding(.horizontal, 20)
            }

            ContributeContinueButton(isEnabled: true, action: onContinue)
        }
        .background(Color(.systemBackground))
    }
}
