import SwiftUI

// Pieces of the redesigned Place Details screen (Figma "Place Details"):
// the full-bleed grade banner under the hero, the maps/call pills, the
// underlined section tabs, the facility chip row, and the "What provided"
// card. Kept here so MockPlaceDetailView stays a layout, not a paint job.

/// Full-bleed accessibility strip directly under the hero image — the grade's
/// own background/foreground pair plus a faint glyph watermark on the right.
struct AccessibilityBanner: View {
    let grade: OverallAccessibility

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: grade.symbolName)
                .font(.system(size: 15, weight: .semibold))
            Text(grade.label.uppercased())
                .font(.system(size: 13, weight: .bold))
                .tracking(0.4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(grade.badgeForeground)
        .padding(.horizontal, 22)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(alignment: .trailing) {
            HStack(spacing: -6) {
                Image(systemName: "figure.roll")
                Image(systemName: grade.symbolName)
            }
            .font(.system(size: 34))
            .foregroundStyle(grade.badgeForeground.opacity(0.12))
            .padding(.trailing, 16)
            .allowsHitTesting(false)
        }
        .background(grade.badgeBackground)
        .clipShape(placeBannerShape)
    }
}

/// The banner tucks under the hero image with only its top corners rounded, so
/// it reads as the content sheet starting rather than as a floating bar.
let placeBannerShape = UnevenRoundedRectangle(
    topLeadingRadius: 18,
    bottomLeadingRadius: 0,
    bottomTrailingRadius: 0,
    topTrailingRadius: 18,
    style: .continuous
)

/// Loading twin of `AccessibilityBanner` — same 44pt strip so the layout does
/// not jump when the real grade resolves.
struct AccessibilityBannerPlaceholder: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 8) {
            ProgressView().controlSize(.mini)
            Text("CHECKING ACCESSIBILITY".localized)
                .font(.system(size: 13, weight: .bold))
                .tracking(0.4)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(.horizontal, 22)
        .frame(height: 44)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.mockSectionBackground)
        .clipShape(placeBannerShape)
        .opacity(shimmer ? 0.6 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}

/// "OPEN IN MAPS" / "CALL" — icon + uppercase label on a grey capsule.
struct PlaceActionPill: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title.localized.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .frame(height: 36)
            .background(Color.mockSectionBackground, in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

/// The three sections of the detail screen. `reviews` carries its own count in
/// the label, so the tab bar shows how much there is before it is opened.
enum PlaceDetailSection: String, CaseIterable, Identifiable {
    case overview
    case reviews
    case photos

    var id: String { rawValue }

    func title(reviewCount: Int) -> String {
        switch self {
        case .overview: "Overview".localized.uppercased()
        case .reviews:
            reviewCount > 0
                ? "\("Reviews".localized.uppercased()) (\(reviewCount))"
                : "Reviews".localized.uppercased()
        case .photos: "Photos".localized.uppercased()
        }
    }
}

/// Underlined tab bar (not the pill segmented control used inside the photos
/// flow) — the selected tab is brand blue with a 2pt rule, and a hairline runs
/// the full width beneath all three.
struct PlaceDetailTabBar: View {
    @Binding var selection: PlaceDetailSection
    let reviewCount: Int

    @Namespace private var underline

    var body: some View {
        HStack(spacing: 0) {
            ForEach(PlaceDetailSection.allCases) { section in
                tab(section)
            }
        }
        .background(alignment: .bottom) {
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(height: 1)
        }
    }

    private func tab(_ section: PlaceDetailSection) -> some View {
        let isSelected = selection == section
        return Button {
            withAnimation(.snappy(duration: 0.22)) { selection = section }
        } label: {
            VStack(spacing: 8) {
                Text(section.title(reviewCount: reviewCount))
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(isSelected ? PhotoPalette.brandBlue : Color.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Group {
                    if isSelected {
                        Rectangle()
                            .fill(PhotoPalette.brandBlue)
                            .matchedGeometryEffect(id: "tabUnderline", in: underline)
                    } else {
                        Color.clear
                    }
                }
                .frame(height: 2)
            }
            .padding(.top, 12)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// Facility selector under the tab bar — one chip per `FacilityKind`, the
/// selected one outlined in brand blue on the plain background.
struct FacilityChipRow: View {
    @Binding var selection: FacilityKind
    var kinds: [FacilityKind] = [.entrance, .elevator, .toilet]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(kinds) { kind in
                    chip(kind)
                }
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func chip(_ kind: FacilityKind) -> some View {
        let isSelected = selection == kind
        return Button {
            withAnimation(.snappy(duration: 0.2)) { selection = kind }
        } label: {
            HStack(spacing: 6) {
                Image(kind.imageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 22, height: 22)
                Text(kind.chipLabel.localized.uppercased())
                    .font(.system(size: 12, weight: .semibold))
                    .tracking(0.2)
            }
            .foregroundStyle(isSelected ? PhotoPalette.brandBlue : Color.primary)
            .padding(.horizontal, 12)
            .frame(height: 48)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color(.systemBackground) : Color.mockSectionBackground)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? PhotoPalette.brandBlue : .clear, lineWidth: 1.5)
            }
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

/// "What provided" — the tags the community confirmed for this facility, laid
/// out as a two-column checklist. Empty and unavailable states are spelled out
/// rather than showing the generic list of things the facility *could* have.
struct WhatProvidedCard: View {
    let tags: [String]
    let isUnavailable: Bool
    let facilityName: String

    private var columns: [GridItem] {
        [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What provided".localized)
                .font(.system(size: 17, weight: .semibold))

            Group {
                if isUnavailable {
                    Text("Not available at this place".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else if tags.isEmpty {
                    Text("No one review this place yet".localized)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                } else {
                    LazyVGrid(columns: columns, alignment: .leading, spacing: 14) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                Text(tag.providedTagLabel)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.mockSectionBackground)
            )
        }
        .accessibilityLabel("\("What provided".localized), \(facilityName)")
    }
}

/// Floating "CONTRIBUTE" pill that sits above the bottom edge of the screen.
struct ContributeFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(.systemBackground))
                    .frame(width: 26, height: 26)
                    .background(Color.primary, in: Circle())
                Text("Contribute".localized.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(.primary)
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .frame(height: 44)
            .background {
                Capsule().fill(Color(.systemBackground).opacity(0.75))
                Capsule().fill(.ultraThinMaterial)
                Capsule().strokeBorder(Color(.separator).opacity(0.35), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

extension FacilityKind {
    /// Short label for the chip row — the plural card titles ("Entrances")
    /// read as headings, the chips want the facility itself.
    var chipLabel: String {
        switch self {
        case .entrance: "Entrance"
        case .elevator: "Elevators"
        case .toilet: "Toilet"
        }
    }
}

extension String {
    /// Review tags arrive upper-cased ("AUTOMATIC DOORS"); the checklist shows
    /// them title-cased the way the mockup does.
    var providedTagLabel: String {
        localized.lowercased().capitalized
    }
}

#Preview("Sections") {
    ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            AccessibilityBanner(grade: .accessible)
            AccessibilityBanner(grade: .partiallyAccessible)
            HStack(spacing: 10) {
                PlaceActionPill(icon: "location.fill", title: "Open in Maps") {}
                PlaceActionPill(icon: "phone.fill", title: "Call") {}
            }
            .padding(.horizontal, 22)
            PlaceDetailTabBar(selection: .constant(.overview), reviewCount: 12)
            FacilityChipRow(selection: .constant(.entrance))
            WhatProvidedCard(
                tags: ["RAMP", "HANDRAIL", "AUTOMATIC DOORS", "MANUAL DOORS", "SECURITY ASSISTANCE"],
                isUnavailable: false,
                facilityName: "Entrance"
            )
            .padding(.horizontal, 22)
            ContributeFloatingButton {}
                .frame(maxWidth: .infinity)
        }
    }
}
