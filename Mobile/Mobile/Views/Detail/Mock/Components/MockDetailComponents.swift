import SwiftUI

// Reusable pieces for the demo "Place Details / Gallery / My Review"
// mockup screens (Views/Detail/Mock, Views/Gallery/Mock). Mock data in,
// SwiftUI/native-look out — no backend calls, no navigation logic here.

extension Color {
    /// Adaptive section background: Light Mode Figma #F2F4F7, Dark Mode tertiarySystemGroupedBackground
    static let mockSectionBackground = Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? .tertiarySystemGroupedBackground : UIColor(red: 242/255, green: 244/255, blue: 247/255, alpha: 1.0)
    })
    /// Matching secondary text color for content on `mockSectionBackground`
    static let mockSecondaryText = Color(uiColor: .secondaryLabel)
}

/// The 4-state accessibility badge (Accessible / Partially Accessible /
/// Not Accessible / No Data Available) — icon + label capsule using each
/// state's exact Figma bg/fg pair (`OverallAccessibility.badgeBackground`/
/// `badgeForeground`), not a single tinted color.
struct AccessibilityBadge: View {
    let grade: OverallAccessibility

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: grade.symbolName)
                .font(.system(size: 12, weight: .semibold))
            Text(grade.label.uppercased())
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(grade.badgeForeground)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(grade.badgeBackground, in: Capsule())
    }
}

/// Read-only icon+label capsule — display tag, not an interactive pill
/// (unlike SelectionPills.swift's selectable pills). Always black icon +
/// text; only the fill inverts depending on what it's sitting on, so it
/// stays visible in both contexts:
///  - `.onGrayCard` (default): white pill on FacilityCard's gray surface.
///  - `.onWhiteCard`: gray (mockSectionBackground) pill on a white card,
///    e.g. My Review's "What provided" section.
struct PillTag: View {
    enum Surface {
        case onGrayCard
        case onWhiteCard
    }

    let label: String
    var surface: Surface = .onGrayCard

    init(tag: MockTag, surface: Surface = .onGrayCard) {
        self.label = tag.label
        self.surface = surface
    }

    init(label: String, surface: Surface = .onGrayCard) {
        self.label = label
        self.surface = surface
    }

    private var fill: Color {
        switch surface {
        case .onGrayCard: Color(.systemBackground)
        case .onWhiteCard: Color.mockSectionBackground
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "door.right.hand.open")
                .font(.system(size: 10, weight: .semibold))
            Text(label.localized)
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(fill, in: Capsule())
    }
}

/// Fixed card heights matching the Figma spec:
/// - 112 pt: single subtitle line (not reviewed / unavailable)
/// - 129 pt: reviewed state with tag pills (potentially two rows)
enum FacilityCardHeight {
    static let compact: CGFloat = 112
    static let expanded: CGFloat = 129

    static func height(for state: FacilityCardState) -> CGFloat {
        switch state {
        case .reviewed(let tags) where !tags.isEmpty: return expanded
        default: return compact
        }
    }
}

/// One row in the Facilities section: icon, title, and a state-driven
/// subtitle (not reviewed / tags from community reviews / unavailable).
/// Used as the label of a NavigationLink inside a List — the native
/// disclosure chevron is provided by the list row, not drawn here.
struct FacilityCard: View {
    let facility: FacilityCardModel

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(facility.iconAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 72, height: 64)

            VStack(alignment: .leading, spacing: 8) {
                Text(facility.title.localized)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                switch facility.state {
                case .notReviewed:
                    Text("Not reviewed yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                case .reviewed(let tags):
                    if tags.isEmpty {
                        Text("Reviewed")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    } else {
                        FlowRow(spacing: 6) {
                            ForEach(tags, id: \.self) { tag in
                                PillTag(label: tag)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                case .unavailable:
                    Text("Not available at this place")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: FacilityCardHeight.height(for: facility.state),
               alignment: .leading)
        .background(Color.mockSectionBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Bespoke capsule segmented control — a floating pill on a track, matching
/// the mockup (native `.pickerStyle(.segmented)` has a different,
/// non-capsule look). Generic over any `Hashable` option set. Two styles:
///  - `.grayTrack` (default, Gallery's filter): gray track, white selected
///    pill with a drop shadow, plain crossfade on selection change.
///  - `.nativeToggle` (My Review's facility tabs): the exact same look as
///    the real `FacilitySegmentedControl` from Views/Photos/Components —
///    same colors (`PhotoPalette`), same sizing (`PhotoMetrics`), and the
///    same `matchedGeometryEffect`-driven sliding capsule instead of a
///    plain opacity crossfade, so it reads as one native toggle component
///    rather than a different-looking lookalike.
struct FilterSegmentedControl<Option: Hashable>: View {
    enum Style {
        case grayTrack
        case nativeToggle
    }

    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option
    var style: Style = .grayTrack

    @Namespace private var indicator

    var body: some View {
        HStack(spacing: style == .nativeToggle ? PhotoMetrics.segmentedSpacing : 4) {
            ForEach(options, id: \.self) { option in
                segment(for: option)
            }
        }
        .padding(style == .nativeToggle ? PhotoMetrics.segmentedPadding : 4)
        .background(trackColor, in: Capsule())
    }

    private var trackColor: Color {
        style == .nativeToggle ? PhotoPalette.segmentedTrack : Color.mockSectionBackground
    }

    @ViewBuilder
    private func segmentIndicator(isSelected: Bool) -> some View {
        if style == .nativeToggle {
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)
                    .opacity(isSelected ? 1 : 0)
                Capsule()
                    .fill(Color.white.opacity(isSelected ? 0.35 : 0))
            }
        } else {
            Capsule().fill(isSelected ? .white : .clear)
        }
    }

    private func segment(for option: Option) -> some View {
        let isSelected = selection == option
        return Button {
            withAnimation(.snappy(duration: 0.22)) {
                selection = option
            }
        } label: {
            Text(label(option))
                .font(.system(size: style == .nativeToggle ? PhotoMetrics.segmentedLabelSize : 12, weight: .semibold))
                .tracking(style == .nativeToggle ? PhotoMetrics.segmentedTracking : 0)
                .foregroundStyle(style == .nativeToggle ? PhotoPalette.primaryLabel : .primary)
                .frame(maxWidth: .infinity)
                .frame(height: style == .nativeToggle ? PhotoMetrics.segmentedItemHeight : nil)
                .padding(.vertical, style == .nativeToggle ? 0 : 8)
                .background {
                    segmentIndicator(isSelected: isSelected)
                        .matchedGeometryEffect(
                            id: "selectedSegment",
                            in: indicator,
                            isSource: isSelected
                        )
                        .shadow(
                            color: .black.opacity(style == .grayTrack && isSelected ? 0.12 : 0),
                            radius: 3, x: 0, y: 1
                        )
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// One photo cell — the real PNG asset when available, otherwise a tinted
/// placeholder with an SF Symbol glyph. Used by MockGalleryView's grid and
/// MockFacilityDetailView's photo strip; caller applies sizing/clipping.
struct MockPhotoTile: View {
    let photo: MockPhoto

    var body: some View {
        if let assetName = photo.assetName {
            Image(assetName)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Rectangle()
                .fill(Color(.tertiarySystemBackground))
                .overlay {
                    Image(systemName: photo.systemImageFallback)
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 20) {
        FacilityCard(facility: FacilityCardModel(
            id: "entrance", key: "entrance", title: "Entrance",
            iconAssetName: "Entrance Asset", state: .reviewed(["RAMP", "HANDRAIL"])
        ))
        FilterSegmentedControl(
            options: ["All", "Entrance", "Elevator", "Toilet"],
            label: { $0 },
            selection: .constant("All")
        )
    }
    .padding()
}
