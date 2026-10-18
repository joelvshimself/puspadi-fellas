import SwiftUI

/// "Contribute Review Category Menus" — first step of the contribute wizard.
struct ContributeReviewCategoryMenusView: View {
    @Binding var selection: Set<ContributeReviewCategory>
    let onBack: () -> Void
    let onContinue: () -> Void

    private let cardWidth: CGFloat = 181
    private let cardHeight: CGFloat = 116
    /// Extra width on each facility option, split evenly on both sides.
    private let optionButtonExtraWidth: CGFloat = 10
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
                .frame(width: cardWidth, height: cardHeight)
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
        .padding(.horizontal, -optionButtonExtraWidth / 2)
    }

    /// SVG icons from `grafical assts`, one per category tile.
    private func categoryIcon(_ category: ContributeReviewCategory) -> some View {
        Image(menuIconAsset(category))
            .renderingMode(.original)
            .resizable()
            .scaledToFit()
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
    @State private var selection: Set<ContributeReviewCategory> = [.entrance]

    var body: some View {
        ContributeReviewCategoryMenusView(
            selection: $selection,
            onBack: {},
            onContinue: {}
        )
    }
}
