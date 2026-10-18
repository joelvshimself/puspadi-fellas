import SwiftUI

/// "Contribute Review Category Menus" — first step of the contribute wizard.
struct ContributeReviewCategoryMenusView: View {
    @Binding var selection: Set<ContributeReviewCategory>
    let onBack: () -> Void
    let onContinue: () -> Void

    private let cardAspectRatio: CGFloat = 855.0 / 580.0
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "", onBack: onBack)
            categoryProgress
                .padding(.horizontal, 20)
                .padding(.bottom, 8)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Help make every visit easier")
                            .font(.title2.bold())
                        Text("Fill in at least one facility to help others know what to expect.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(ContributeReviewCategory.menuOrder) { category in
                            categoryCard(category)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(
                isEnabled: !selection.isEmpty,
                action: onContinue
            )
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
    }

    private var categoryProgress: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray5))
                    .frame(height: 4)
                Capsule()
                    .fill(Color.accentColor)
                    .frame(width: geo.size.width * 0.12, height: 4)
            }
        }
        .frame(height: 4)
    }

    @ViewBuilder
    private func categoryCard(_ category: ContributeReviewCategory) -> some View {
        let isSelected = selection.contains(category)
        Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected { selection.remove(category) } else { selection.insert(category) }
            }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 12) {
                    categoryIcon(category)
                        .frame(height: 64)
                    HStack(alignment: .center, spacing: 4) {
                        Text(category.menuTitle.uppercased())
                            .font(.system(size: 14, weight: .semibold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .foregroundStyle(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity)
                .aspectRatio(cardAspectRatio, contentMode: .fit)
                .background(
                    isSelected ? Color.accentColor.opacity(0.12) : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                }

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.accentColor, in: Circle())
                        .offset(x: -6, y: 6)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func categoryIcon(_ category: ContributeReviewCategory) -> some View {
        switch category {
        case .entrance:
            Image("entranceasset").resizable().scaledToFit()
        case .elevator:
            Image("elevatorasset").resizable().scaledToFit()
        case .toilet:
            Image("bathroomasset").resizable().scaledToFit()
        case .outdoorPathways:
            Image("pathwayicon").resizable().scaledToFit()
        case .seating:
            Image("seatingasset").resizable().scaledToFit()
        case .parking:
            Image("parkingasset").resizable().scaledToFit()
        }
    }
}
