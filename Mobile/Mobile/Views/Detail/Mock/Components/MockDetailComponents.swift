import SwiftUI

// Reusable pieces for the demo "Place Details / Gallery / My Review"
// mockup screens (Views/Detail/Mock, Views/Gallery/Mock). Mock data in,
// SwiftUI/native-look out — no backend calls, no navigation logic here.

extension Color {
    /// The one light-gray "sub background" / small-pill fill used
    /// throughout these mockup screens (facility cards, tag pills, filter
    /// tracks, the gray tabbed section on My Review). Figma spec #F2F4F7 —
    /// not the semantic `secondarySystemBackground`/`tertiarySystemBackground`
    /// tones, which render a visibly different (more neutral/darker) gray
    /// than the design's cool light gray.
    static let mockSectionBackground = Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
    /// Matching secondary text color for content on `mockSectionBackground`
    /// (Figma #5F5F5F).
    static let mockSecondaryText = Color(red: 95 / 255, green: 95 / 255, blue: 95 / 255)
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

    let tag: MockTag
    var surface: Surface = .onGrayCard

    private var fill: Color {
        switch surface {
        case .onGrayCard: Color(.systemBackground)
        case .onWhiteCard: Color.mockSectionBackground
        }
    }

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: "door.right.hand.open")
                .font(.system(size: 10, weight: .semibold))
            Text(tag.label)
                .font(.system(size: 10, weight: .regular))
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(fill, in: Capsule())
    }
}

/// One row in the Facilities section: icon box, title, wrapped tags (or an
/// empty-state description), trailing chevron. Display-only — no detail
/// screen behind it, tap does nothing.
struct FacilityCard: View {
    let facility: MockFacility

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(facility.iconAssetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 72)

            VStack(alignment: .leading, spacing: 8) {
                Text(facility.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)

                if let emptyStateText = facility.emptyStateText {
                    Text(emptyStateText)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    FlowRow(spacing: 8) {
                        ForEach(facility.tags) { tag in
                            PillTag(tag: tag)
                        }
                        if facility.key == "entrance", MockData.entranceExtraCount > 0 {
                            PillTag(tag: MockTag(label: "+\(MockData.entranceExtraCount)"))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            // Claims all remaining width ahead of the fixed-size chevron,
            // instead of a trailing Spacer(minLength: 0) — that left the
            // text column measuring its own intrinsic (narrow) width,
            // wrapping the Toilet empty-state text far earlier than the
            // available space allowed.
            .layoutPriority(1)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mockSectionBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

/// Bespoke capsule segmented control — a floating pill on a track, matching
/// the mockup (native `.pickerStyle(.segmented)` has a different,
/// non-capsule look). Generic over any `Hashable` option set. Two color
/// arrangements depending on what it sits on:
///  - `.grayTrack` (default, Gallery's filter): gray track, white
///    selected pill — matches Gallery's white page background.
///  - `.whiteTrack` (My Review's facility tabs): white track, gray
///    selected pill — sits on My Review's own gray section background,
///    so the coloring needs to invert to stay visible.
struct FilterSegmentedControl<Option: Hashable>: View {
    enum Style {
        case grayTrack
        case whiteTrack
    }

    let options: [Option]
    let label: (Option) -> String
    @Binding var selection: Option
    var style: Style = .grayTrack

    private var trackColor: Color {
        style == .grayTrack ? Color.mockSectionBackground : Color(.systemBackground)
    }

    private var selectedColor: Color {
        style == .grayTrack ? Color(.systemBackground) : Color.mockSectionBackground
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selection == option ? selectedColor : Color.clear,
                            in: Capsule()
                        )
                        .shadow(
                            color: .black.opacity(selection == option && style == .grayTrack ? 0.12 : 0),
                            radius: 3, x: 0, y: 1
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(trackColor, in: Capsule())
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
        ForEach(MockData.facilities) { facility in
            FacilityCard(facility: facility)
        }
        FilterSegmentedControl(
            options: ["All", "Entrance", "Elevator", "Toilet"],
            label: { $0 },
            selection: .constant("All")
        )
    }
    .padding()
}
