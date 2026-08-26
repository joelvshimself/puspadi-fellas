import SwiftUI

/// `EntranceLocation` (Models/ReviewDraft.swift) has no `Identifiable`
/// conformance in its home file since the real wizard never lets the user
/// pick one — it always walks both. This flow does let the user pick
/// (matches the mockup's "Where did you enter?" screen), so it needs
/// `SelectionPills<EntranceLocation>` to work; conformance added here
/// rather than in ReviewDraft.swift to keep that file untouched.
extension EntranceLocation: Identifiable, CaseIterable {
    var id: String { rawValue }
    static var allCases: [EntranceLocation] { [.lobby, .basement] }

    var displayLabel: String {
        switch self {
        case .lobby: "Lobby".localized
        case .basement: "Basement".localized
        }
    }
}

/// "Which entrances did you use?" — Lobby/Basement multi-select, shown as
/// the first question of the flow (replaces the old category-picker start).
struct ContributeEntranceLocationStepView: View {
    let facilityName: String
    let progress: (current: Int, total: Int)
    @Binding var selection: Set<EntranceLocation>
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "Entrances".localized, onBack: onBack)
            ContributeStepProgressBar(currentStep: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image("Entrance Mall Asset")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .scaleEffect(1.05)
                        .frame(height: 180)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Which entrances did you use?".localized)
                            .font(.title2.bold())
                        Text("You can select multiple answers".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(spacing: 12) {
                        ForEach(EntranceLocation.allCases) { location in
                            entranceRow(location)
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
    }

    private func entranceRow(_ location: EntranceLocation) -> some View {
        let isSelected = selection.contains(location)
        return Button {
            withAnimation(.snappy(duration: 0.2)) {
                if isSelected {
                    selection.remove(location)
                } else {
                    selection.insert(location)
                }
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "door.right.hand.open")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    .frame(width: 24)

                Text(location.displayLabel)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(isSelected ? Color.accentColor : .primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.accentColor : Color(.tertiaryLabel))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(Color(.secondarySystemBackground), in: Capsule())
            .overlay {
                Capsule()
                    .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

/// One facility's tag-multiselect question screen — the mockup's "What did
/// the entrance have?"/"What do the elevators have?"/"What does the toilet
/// have?" screens. Reused for all 3 facility kinds.
struct ContributeFacilityQuestionStepView: View {
    let kind: FacilityKind
    let navTitle: String
    let questionTitle: String
    let progress: (current: Int, total: Int)
    @Binding var selection: Set<ContributeTagOption>
    /// Overrides for entrance's per-location screens (distinct illustration
    /// + chip catalog per Lobby/Basement) — nil for elevator/toilet, which
    /// still fall back to `ContributeFacilityIllustration`/`ContributeReviewTags.tags(for:)`.
    var illustrationAssetName: String?
    var optionsOverride: [ContributeTagOption]?
    var subStepProgress: CGFloat = 0.35
    let onBack: () -> Void
    let onContinue: () -> Void
    private var options: [ContributeTagOption] { optionsOverride ?? ContributeReviewTags.tags(for: kind) }
    private var stepNumber: Int {
        switch kind {
        case .entrance: 1
        case .elevator: 2
        case .toilet: 3
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let assetName = illustrationAssetName {
                        Image(assetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(1.05)
                            .frame(height: 180)
                    } else {
                        ContributeFacilityIllustration(kind: kind)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(questionTitle.localized)
                            .font(.title2.bold())
                        Text("You can select multiple answers".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Own chip row rather than MultiSelectPills: the mockup's
                    // chips carry a leading SF Symbol and mark selection with
                    // a blue outline + blue label (white fill kept), where
                    // MultiSelectPills is text-only with a solid blue fill.
                    FlowRow(spacing: 10) {
                        ForEach(options) { option in
                            ContributeTagChip(
                                option: option,
                                isSelected: selection.contains(option)
                            ) {
                                toggle(option)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
    }

    private func toggle(_ option: ContributeTagOption) {
        withAnimation(.snappy(duration: 0.18)) {
            if selection.contains(option) {
                selection.remove(option)
            } else {
                selection.insert(option)
            }
        }
    }
}

/// One selectable answer chip — icon + label, blue outline/label when
/// selected (matches the mockup's "Ramp"/"Wide Entrance"/"Grab Bars"
/// chips). Multi-select: each chip toggles independently.
struct ContributeTagChip: View {
    let option: ContributeTagOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                tagIcon
                    .font(.system(size: 12, weight: .medium))
                Text(option.label.localized.capitalized)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(isSelected ? Color.accentColor : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.08) : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule().strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    @ViewBuilder
    private var tagIcon: some View {
        if option.isSystemSymbol {
            Image(systemName: option.symbol)
        } else {
            Image(option.symbol)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 12, height: 12)
        }
    }
}

/// Shared hero illustration for the survey steps. Deliberately uses the
/// `* Survey Asset` imagesets, NOT the `* Asset` ones — those are the
/// line-art icons the Place Details facility cards render, and the two
/// sets are not interchangeable.
struct ContributeFacilityIllustration: View {
    let kind: FacilityKind

    private var assetName: String {
        switch kind {
        case .entrance: "Entrance Survey Asset"
        case .elevator: "Elevator Survey Asset"
        case .toilet: "Toilet Survey Asset"
        }
    }

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .scaleEffect(1.05)
            .frame(height: 180)
    }
}

/// The pinned bottom "Continue" button shared by every step in this flow —
/// full-width blue capsule-ish rounded rect, disabled/gray until answered.
struct ContributeContinueButton: View {
    var title: String = "Continue"
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title.localized)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    isEnabled ? Color.accentColor : Color(.systemGray4),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color(.systemBackground))
    }
}

#Preview {
    ContributeFacilityQuestionStepView(
        kind: .entrance,
        navTitle: "Entrances",
        questionTitle: "What did the entrance have?",
        progress: (2, 6),
        selection: .constant([]),
        onBack: {},
        onContinue: {}
    )
}
