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

/// "Where did you enter?" — Lobby/Basement single-select, shown before
/// Entrance's tag-question screen (the mockup's Entrance Form Q1).
struct ContributeEntranceLocationStepView: View {
    let facilityName: String
    let progress: (current: Int, total: Int)
    @Binding var selection: EntranceLocation?
    let onBack: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "Entrances".localized, onBack: onBack)
            ReviewProgressBar(currentIndex: progress.current, totalSteps: progress.total)
                .padding(.horizontal, PhotoMetrics.toolbarHorizontalPadding)
                .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ContributeFacilityIllustration(kind: .entrance)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Where did you enter?".localized)
                            .font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    SelectionPills(
                        options: EntranceLocation.allCases,
                        label: \.displayLabel,
                        selection: $selection
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: selection != nil, action: onContinue)
        }
        .background(Color(.systemBackground))
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
    let onBack: () -> Void
    let onContinue: () -> Void

    private var options: [ContributeTagOption] { ContributeReviewTags.tags(for: kind) }

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
            ReviewProgressBar(currentIndex: progress.current, totalSteps: progress.total)
                .padding(.horizontal, PhotoMetrics.toolbarHorizontalPadding)
                .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ContributeFacilityIllustration(kind: kind)

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
                Image(systemName: option.symbol)
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
            .frame(height: 220)
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
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
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
