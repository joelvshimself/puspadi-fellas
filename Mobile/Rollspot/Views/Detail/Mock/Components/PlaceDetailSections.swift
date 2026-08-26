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

/// Floating "CONTRIBUTE" pill that sits above the bottom edge of the screen —
/// real Liquid Glass (same treatment as the home screen's buttons), so the
/// content scrolling beneath it refracts through the capsule.
struct ContributeFloatingButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            // Explicit black/white, not .primary: the glass surface applies
            // vibrancy to semantic colors, which washed the design's solid
            // black plus-circle down to grey.
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 26, height: 26)
                    .background(Color.black, in: Circle())
                Text("Contribute".localized.uppercased())
                    .font(.system(size: 13, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Color.black)
            }
            .padding(.leading, 8)
            .padding(.trailing, 18)
            .frame(height: 44)
            .contentShape(Capsule())
            .homeGlass(in: Capsule(), tint: .white.opacity(0.30))
            .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }
}

/// Soft blue glow rising from the screen bottom behind the CONTRIBUTE pill
/// (the design's Ellipse 8 treatment, same one the home sheet sits on).
struct ContributeGlow: View {
    var body: some View {
        Ellipse()
            .fill(SheetPalette.glow)
            .frame(width: SheetMetrics.glowWidth, height: SheetMetrics.glowHeight)
            .blur(radius: SheetMetrics.glowBlur)
            .opacity(SheetMetrics.glowOpacity)
            .offset(y: SheetMetrics.glowOffsetY)
            .allowsHitTesting(false)
            .ignoresSafeArea()
    }
}

/// Loading twin of the tabbed content — shimmering stand-ins for the tab bar,
/// chip row, and cards, so "still fetching" never looks like "nothing here".
/// The real layout (full or empty) is only chosen once the store resolves.
struct PlaceDetailLoadingSkeleton: View {
    @State private var shimmer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 24) {
                bar(width: 90)
                bar(width: 90)
                bar(width: 70)
            }
            HStack(spacing: 10) {
                block(width: 108, height: 48, radius: 12)
                block(width: 108, height: 48, radius: 12)
                block(width: 90, height: 48, radius: 12)
            }
            block(width: nil, height: 110, radius: 12)
            block(width: nil, height: 140, radius: 12)
        }
        .opacity(shimmer ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
        .accessibilityLabel("Loading place details".localized)
    }

    private func bar(width: CGFloat) -> some View {
        Capsule().fill(Color.mockSectionBackground).frame(width: width, height: 14)
    }

    private func block(width: CGFloat?, height: CGFloat, radius: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color.mockSectionBackground)
            .frame(maxWidth: width ?? .infinity)
            .frame(height: height)
    }
}

/// Shimmering hero image placeholder shown while place details and hero photos are loading.
struct HeroLoadingSkeleton: View {
    var width: CGFloat? = nil
    var height: CGFloat = 253
    @State private var shimmerPhase: CGFloat = -1

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(.secondarySystemBackground),
                    Color(.tertiarySystemBackground),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.30), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: max(geo.size.width * 0.6, 100))
                .offset(x: shimmerPhase * max(geo.size.width, 100) * 1.6)
                .blendMode(.plusLighter)
            }

            VStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.system(size: 34, weight: .light))
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(height: height)
        .frame(maxWidth: width ?? .infinity)
        .clipped()
        .onAppear {
            withAnimation(.linear(duration: 1.3).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
        .accessibilityLabel("Loading photo".localized)
    }
}

/// Settled placeholder when a venue has no photos after loading finishes.
struct PlaceEmptyHeroPlaceholder: View {
    var height: CGFloat = 253

    var body: some View {
        ZStack {
            Rectangle().fill(Color(.secondarySystemBackground))
            VStack(spacing: 8) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 36, weight: .light))
                    .foregroundStyle(.tertiary)
                Text("No Photos Available".localized)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

/// First-visit spotlight on the CONTRIBUTE pill (Figma "Intro to contribute"):
/// the screen dims, a white callout explains why contributions matter, and a
/// pointer aims at the pill — which stays bright above the dim.
struct ContributeIntroOverlay: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [.black.opacity(0.45), Color.accentColor.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .contentShape(Rectangle())
            .onTapGesture(perform: onDismiss)

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color.orange))
                        Text("Share what you know".localized)
                            .font(.system(size: 16, weight: .bold))
                    }
                    Text("Help others know what to expect by adding accessibility information.".localized)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(16)
                .frame(maxWidth: 280)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )

                Triangle()
                    .fill(Color(.systemBackground))
                    .frame(width: 18, height: 9)
            }
            // Sits just above the CONTRIBUTE pill (44pt pill + 20pt inset).
            .padding(.bottom, 76)
        }
    }

    private struct Triangle: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            path.closeSubpath()
            return path
        }
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
