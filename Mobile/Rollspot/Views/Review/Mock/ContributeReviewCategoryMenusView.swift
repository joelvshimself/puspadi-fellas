import SwiftUI

enum ContributeCategoryStatus: Equatable {
    case inProgress
    case complete
}

/// "Contribute Review Category Menus" (Figma): Not filled → Form in progress (autosave) → Completed form.
/// Measurements are the frame's, at 393pt wide.
struct ContributeReviewCategoryMenusView: View {
    let status: [ContributeReviewCategory: ContributeCategoryStatus]
    let canContinue: Bool
    var isSubmitting: Bool = false
    let onBack: () -> Void
    let onOpen: (ContributeReviewCategory) -> Void
    let onContinue: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // The menu is the first of four sections: a short fill, as in the design.
            ContributeStepProgressBar(currentStep: 1, subStepProgress: 0.35)
            PhotoFlowHeader(title: "", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 34) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Help make every visit easier".localized)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(ContributePalette.text)
                        Text("Fill in at least one facility to help others know what to expect.".localized)
                            .font(.system(size: 14))
                            .foregroundStyle(ContributePalette.secondaryText)
                            .frame(maxWidth: 250, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ContributeReviewCategory.menuOrder) { category in
                            categoryCard(category)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 34)
            }

            // "Continue" (disabled) until a section is complete, then "Submit".
            ContributeContinueButton(
                title: canContinue ? "Submit" : "Continue",
                isLoading: isSubmitting,
                isEnabled: canContinue,
                action: onContinue
            )
        }
        .background(Color(.systemBackground))
    }

    private func categoryCard(_ category: ContributeReviewCategory) -> some View {
        let cardStatus = status[category]
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            onOpen(category)
        } label: {
            VStack(spacing: 18) {
                Image(menuIconAsset(category))
                    .renderingMode(.original)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 30)
                HStack(alignment: .center, spacing: 6) {
                    Text(category.menuTitle.uppercased())
                        .font(.system(size: 15, weight: .bold))
                        .tracking(1.0)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .foregroundStyle(ContributePalette.text)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(ContributePalette.chevron)
                }
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
            .frame(height: 115)
            .background(cardStatus == .complete ? ContributePalette.completeFill : ContributePalette.fill, in: shape)
            .overlay(alignment: .topTrailing) {
                statusBadge(cardStatus)
                    .padding(.top, 8)
                    .padding(.trailing, 8)
            }
            .contentShape(shape)
            .animation(.easeOut(duration: 0.2), value: cardStatus)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(category.menuTitle.localized)
        .accessibilityValue(statusDescription(cardStatus))
    }

    @ViewBuilder
    private func statusBadge(_ status: ContributeCategoryStatus?) -> some View {
        switch status {
        case .complete:
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 19, height: 19)
                .background(ContributePalette.blue, in: Circle())
                .transition(.scale(scale: 0.6).combined(with: .opacity))
        case .inProgress:
            // Autosaved, not finished: a partial ring on a faint track.
            ZStack {
                Circle().stroke(ContributePalette.blue.opacity(0.15), lineWidth: 2.5)
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(ContributePalette.blue, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 17, height: 17)
            .padding(1)
            .transition(.opacity)
        case nil:
            EmptyView()
        }
    }

    private func statusDescription(_ status: ContributeCategoryStatus?) -> String {
        switch status {
        case .complete: "Completed".localized
        case .inProgress: "In progress".localized
        case nil: ""
        }
    }

    private func menuIconAsset(_ category: ContributeReviewCategory) -> String {
        switch category {
        case .entrance: "Menu Entrance"
        case .elevator: "Menu Elevator"
        case .toilet: "Menu Toilet"
        case .outdoorPathways: "Menu Pathway"
        case .seating: "Menu Seating"
        case .parking: "Menu Parking"
        }
    }
}

#Preview {
    ContributeReviewCategoryMenusPreview()
}

private struct ContributeReviewCategoryMenusPreview: View {
    var body: some View {
        ContributeReviewCategoryMenusView(
            status: [.entrance: .inProgress, .elevator: .complete],
            canContinue: true,
            onBack: {},
            onOpen: { _ in },
            onContinue: {}
        )
    }
}
