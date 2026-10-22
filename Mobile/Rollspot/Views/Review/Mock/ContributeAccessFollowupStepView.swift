import SwiftUI

/// Single-select follow-up question — entrance's Ramp/Handrail screens
/// (shown only when that chip was picked) and every elevator question.
/// Single-select rows (not the usual multi-select chips), and picking
/// `photoRevealOption` ("Not sure") reveals an inline Add Photos box, same
/// visual as ContributePhotosNotesStepView's but scoped to this question.
struct ContributeAccessFollowupStepView: View {
    let navTitle: String
    let illustrationAssetName: String
    let eyebrow: String
    let questionTitle: String
    let progress: (current: Int, total: Int)
    let options: [String]
    /// Which option (last one, "Not sure") reveals the Add Photos box.
    let photoRevealOption: String
    @Binding var selection: String?
    @Binding var note: ReviewNoteDraft
    /// Cap for this photo box. Evidence boxes pass the pass-wide remainder.
    var photoLimit: Int = ReviewNoteDraft.maxPhotos
    var stepNumber: Int = 1
    var subStepProgress: CGFloat = 0.35
    /// Tapping a choice continues immediately and hides the Continue button.
    var advancesOnSelect: Bool = false
    /// When set, a looping video replaces the still illustration.
    var loopingVideoName: String? = nil
    var videoInfoTitle: String = ""
    var videoInfoSections: [(title: String, body: String)] = []
    /// When set, the info sheet repeats this looping video above the copy.
    var infoVideoName: String? = nil
    let onBack: () -> Void
    let onContinue: () -> Void

    private static let bottomID = "bottom"

    @State private var showPhotosSection = false
    @State private var isAdvancing = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        illustration
                            .padding(.top, advancesOnSelect ? 26 : 14)

                        ContributeQuestionHeading(eyebrow: eyebrow, title: questionTitle)
                            .padding(.top, advancesOnSelect ? 40 : 34)

                        if !advancesOnSelect {
                            VStack(spacing: ContributeQuestionMetrics.optionSpacing) {
                                ForEach(options, id: \.self) { option in
                                    ContributeOptionRow(title: option, isSelected: selection == option) {
                                        selection = option
                                    }
                                }
                            }
                            .padding(.top, 18)
                        }

                        if showPhotosSection {
                            // "Not sure": evidence photos for this question.
                            ContributePhotoStrip(note: $note, limit: photoLimit, style: .reveal)
                                .padding(.top, 12)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                        Color.clear.frame(height: 1).id(Self.bottomID)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
                }
                .onAppear { showPhotosSection = !photoRevealOption.isEmpty && selection == photoRevealOption }
                .onChange(of: selection) { _, newValue in
                    let reveal = !photoRevealOption.isEmpty && newValue == photoRevealOption
                    guard reveal != showPhotosSection else { return }
                    withAnimation(.easeOut(duration: 0.25)) { showPhotosSection = reveal }
                    if reveal {
                        // Bring the new photo box into view.
                        Task { @MainActor in
                            try? await Task.sleep(nanoseconds: 60_000_000)
                            withAnimation(.easeOut(duration: 0.3)) { proxy.scrollTo(Self.bottomID, anchor: .bottom) }
                        }
                    }
                }
            }

            if advancesOnSelect {
                // "Review another …?": the answers sit where Continue usually is.
                VStack(spacing: 10) {
                    ForEach(options, id: \.self) { option in
                        ContributeChoiceButton(title: option, isSelected: selection == option) { choose(option) }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, -14)
            } else {
                ContributeContinueButton(isEnabled: selection != nil, action: onContinue)
            }
        }
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var illustration: some View {
        if let loopingVideoName {
            RampLoopVideoCard(
                resourceName: loopingVideoName,
                infoTitle: videoInfoTitle,
                infoSections: videoInfoSections,
                infoVideoName: infoVideoName ?? loopingVideoName
            )
            .id(loopingVideoName)
        } else if !videoInfoSections.isEmpty {
            FollowUpStillCard(imageName: illustrationAssetName, infoTitle: videoInfoTitle, infoSections: videoInfoSections)
        } else {
            ContributeIllustration(name: illustrationAssetName)
        }
    }

    /// Tap → the pill fills blue → the flow moves on a beat later, so the choice is seen.
    private func choose(_ option: String) {
        guard !isAdvancing else { return }
        isAdvancing = true
        selection = option
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 280_000_000)
            onContinue()
            isAdvancing = false
        }
    }
}

#Preview {
    ContributeAccessFollowupStepView(
        navTitle: "Entrances",
        illustrationAssetName: "Lobby Asset",
        eyebrow: "Ramps",
        questionTitle: "Could you push your wheelchair up the ramp without help?",
        progress: (2, 6),
        options: ["Yes", "With a push", "Too steep", "Not sure"],
        photoRevealOption: "Not sure",
        selection: .constant(nil),
        note: .constant(ReviewNoteDraft()),
        onBack: {},
        onContinue: {}
    )
}
