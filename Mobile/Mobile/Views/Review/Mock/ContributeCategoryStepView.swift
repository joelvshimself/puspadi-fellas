import SwiftUI

/// Screen 1 of the Contribute Review flow — "What accessible facilities
/// does {place} have?" multi-select over the 3 `FacilityKind`s. Skipped
/// entirely when the flow is entered from one specific facility's "Add
/// Review" button (see ContributeReviewFlowView's `startingFacility`).
struct ContributeCategoryStepView: View {
    let placeName: String
    @Binding var selection: Set<FacilityKind>
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "Contribute", onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ContributeMallIllustration()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("What accessible facilities does \(placeName) have?")
                            .font(.title2.bold())
                        Text("You can select multiple answers")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Explicit order — `FacilityKind.allCases` declares
                    // elevator/toilet/entrance, but the design lists
                    // Entrances, Elevators, then Accessible Toilets.
                    VStack(spacing: 12) {
                        ForEach([FacilityKind.entrance, .elevator, .toilet]) { kind in
                            categoryRow(kind)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
    }

    private func categoryRow(_ kind: FacilityKind) -> some View {
        let isSelected = selection.contains(kind)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected {
                    selection.remove(kind)
                } else {
                    selection.insert(kind)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: categoryIcon(kind))
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 24)

                Text(categoryLabel(kind))
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }

    /// The design spells the toilet row out as "Accessible Toilets", where
    /// `FacilityKind.title` is just "Toilets" (that shorter form is what
    /// the facility detail screens want).
    private func categoryLabel(_ kind: FacilityKind) -> String {
        switch kind {
        case .entrance: "Entrances"
        case .elevator: "Elevators"
        case .toilet: "Accessible Toilets"
        }
    }

    private func categoryIcon(_ kind: FacilityKind) -> String {
        switch kind {
        case .entrance: "door.left.hand.closed"
        case .elevator: "arrow.up.arrow.down.circle"
        case .toilet: "figure.roll"
        }
    }
}

/// Mall Asset illustration used only on the category-picker screen.
struct ContributeMallIllustration: View {
    var body: some View {
        Image("Mall Asset")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: 220)
    }
}

#Preview {
    ContributeCategoryStepView(
        placeName: "Park23 Mall",
        selection: .constant([.entrance]),
        onBack: {},
        onContinue: {}
    )
}
