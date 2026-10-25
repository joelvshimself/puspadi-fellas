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
    @State private var showEntranceInfo = false

    var body: some View {
        VStack(spacing: 0) {
            ContributeStepProgressBar(currentStep: 1)
            PhotoFlowHeader(title: "Entrances".localized, onBack: onBack)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ContributeIllustration(name: "Lobby Asset")
                        .padding(.top, 26)

                    ContributeQuestionHeading(
                        title: "Where can you find the accessible entrances?",
                        subtitle: "You can select multiple places"
                    ) {
                        Button {
                            showEntranceInfo = true
                        } label: {
                            Image(systemName: "info")
                                .font(.system(size: 9, weight: .heavy))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Color(designHex: 0xA8ABB0), in: Circle())
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, -8)
                        .accessibilityLabel("Accessible entrance info".localized)
                    }
                    .padding(.top, 40)

                    VStack(spacing: ContributeQuestionMetrics.optionSpacing) {
                        ForEach(EntranceLocation.allCases) { location in
                            ContributeOptionRow(
                                title: location.displayLabel,
                                isSelected: selection.contains(location),
                                leadingSymbol: "door.left.hand.open",
                                showsRadio: true
                            ) {
                                if selection.contains(location) {
                                    selection.remove(location)
                                } else {
                                    selection.insert(location)
                                }
                            }
                        }
                    }
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
            }

            ContributeContinueButton(isEnabled: !selection.isEmpty, action: onContinue)
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showEntranceInfo) {
            AccessibleEntranceInfoSheet()
        }
    }
}

private struct AccessibleEntranceInfoSheet: View {
    private let points = [
        "Ramps",
        "Handrails",
        "Automatic doors",
        "Security assistance",
        "Wheelchair loans available",
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image("Lobby Asset")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)

                Text("Accessible Entrance")
                    .font(.title2.bold())

                Text("Entrances require non-obstructed pathways for someone to navigate independently to be accessible.")
                    .font(.body)
                    .foregroundStyle(.secondary)

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(points, id: \.self) { point in
                        Text("•  \(point)")
                            .font(.body)
                    }
                }
            }
            .padding(24)
            .padding(.top, 8)
        }
        .presentationDragIndicator(.visible)
        .presentationDetents([.medium, .large])
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
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Group {
                        if let assetName = illustrationAssetName {
                            ContributeIllustration(name: assetName)
                        } else {
                            ContributeFacilityIllustration(kind: kind)
                        }
                    }
                    // Tag screens sit the illustration lower than the location screen (Figma).
                    .padding(.top, 66)

                    ContributeQuestionHeading(title: questionTitle, subtitle: "You can select multiple answers")
                        .padding(.top, 40)

                    // Icon chips; picked ones turn white with a blue outline (Figma "What does the lobby have?").
                    FlowRow(spacing: 10) {
                        ForEach(options) { option in
                            ContributeTagChip(option: option, isSelected: selection.contains(option)) {
                                toggle(option)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 18)
                }
                .padding(.horizontal, 20)
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
            HStack(spacing: 8) {
                tagIcon
                    .font(.system(size: 13, weight: .medium))
                Text(option.label.localized.capitalized)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(isSelected ? ContributePalette.blue : Color(designHex: 0x3E4042))
            .padding(.horizontal, 16)
            .frame(height: 38)
            .background(Capsule().fill(isSelected ? Color.white : ContributePalette.fill))
            .overlay(Capsule().strokeBorder(ContributePalette.blue.opacity(isSelected ? 1 : 0), lineWidth: 1.5))
            .contentShape(Capsule())
            .animation(.easeOut(duration: 0.15), value: isSelected)
        }
        .buttonStyle(PressableButtonStyle())
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
                .frame(width: 13, height: 13)
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
            .frame(height: ContributeQuestionMetrics.illustrationHeight)
            .frame(maxWidth: .infinity)
    }
}

/// The pinned bottom "Continue" button shared by every step in this flow —
/// full-width blue capsule-ish rounded rect, disabled/gray until answered.
struct ContributeContinueButton: View {
    var title: String = "Continue"
    var isLoading: Bool = false
    let isEnabled: Bool
    let action: () -> Void

    private var isInteractive: Bool {
        isEnabled && !isLoading
    }

    var body: some View {
        Button(action: action) {
            Group {
                if isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(title.localized)
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(isInteractive || isLoading ? Color.white : ContributePalette.disabledText)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                isInteractive || isLoading ? ContributePalette.blue : ContributePalette.disabledFill,
                in: Capsule()
            )
            .animation(.easeOut(duration: 0.2), value: isInteractive)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!isInteractive)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        // The design sits the button down into the home-indicator area.
        .padding(.bottom, -14)
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
