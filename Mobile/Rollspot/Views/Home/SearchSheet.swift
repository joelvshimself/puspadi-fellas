import MapKit
import UIKit
import SwiftUI

enum HomeRoute: Hashable {
    case place(Place)
    case saved
    case contribute
    case profile(ProfileTab = .reviews)
}

// MARK: - Design tokens

enum SheetPalette {
    /// #0099FF — the focused field's border.
    static let brandBlue = Color(red: 0, green: 0.6, blue: 1)
    /// #0088FF — leading glyphs on list rows.
    static let accentBlue = Color(red: 0, green: 0.533, blue: 1)
    /// Ellipse 8 #389CFF — the blurred blob behind the sheet that gives the
    /// glass its blue cast.
    static let glow = Color(red: 0.220, green: 0.612, blue: 1)
    /// The rgba(181,181,181,0.6) scrim over the map while searching.
    static let searchScrim = Color(white: 181.0 / 255.0)
    /// The drag handle. White washed out against the light glass, so it takes a
    /// neutral grey — swap this for `brandBlue` if you want it tinted.
    static let grabber = Color(white: 0.55)
    /// Hairline rim shared by the circular buttons and the search pill.
    static let rimGradient = LinearGradient(
        colors: [.black.opacity(0.06), .black.opacity(0.16)],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum SheetMetrics {
    // Peek — Homepage 285:1323
    static let grabberWidth: CGFloat = 48
    static let grabberHeight: CGFloat = 6
    static let grabberTopPadding: CGFloat = 10
    static let grabberBlockHeight: CGFloat = 16

    /// These two must still sum with the grabber and field to 102pt — that is
    /// the detent floor below which iOS squeezes the sheet's contents. To
    /// tighten the gap under the pill, move points from bottom to top.
    static let rowTopPadding: CGFloat = 10
    static let rowBottomPadding: CGFloat = 15
    static let horizontalPadding: CGFloat = 16

    static let fieldHeight: CGFloat = 40
    static let fieldSpacing: CGFloat = 8
    static let fieldFillOpacity: CGFloat = 0.8
    static let fieldBorderWidth: CGFloat = 2

    static let textSize: CGFloat = 17
    static let textTracking: CGFloat = -0.43
    static let textOpacity: CGFloat = 0.8
    static let placeholderOpacity: CGFloat = 0.3

    // MARK: Collapsed sheet height (the detent)
    //
    // Must equal what the peek CONTENT actually renders. If the detent is
    // smaller than the content, iOS squeezes the sheet instead of honouring it
    // — the 6pt grabber is the first thing to disappear.
    //
    // The catch: the grabber block renders `grabberTopPadding + grabberHeight`
    // (18 + 6 = 24), NOT `grabberBlockHeight` (16). `minHeight` is only a
    // floor, so raising grabberTopPadding grows the block while the old
    // formula kept counting 16 — leaving the detent 8pt short.
    //
    // Swap which line is commented to compare the two.

    //  OLD — under-counts the grabber block by 8pt (gives 92):
    //  static let peekHeight: CGFloat =
    //      grabberBlockHeight + rowTopPadding + fieldHeight + rowBottomPadding

    //  CURRENT — counts the block as it really lays out (gives 100):
    static let peekHeight: CGFloat =
        max(grabberBlockHeight, grabberTopPadding + grabberHeight)
            + rowTopPadding + fieldHeight + rowBottomPadding

    //  Knobs, for reference — change these, not peekHeight:
    //    grabberTopPadding   10   space above the grabber
    //    rowTopPadding       10   grabber block -> pill
    //    fieldHeight         40   the pill itself
    //    rowBottomPadding    15   pill -> sheet bottom
    //    horizontalPadding   16   pill left/right inset

    // List rows — List/Location 285:2069
    static let rowCornerRadius: CGFloat = 16
    static let rowSpacing: CGFloat = 8
    static let rowIconWidth: CGFloat = 22
    static let rowTitleSize: CGFloat = 15
    static let rowSubtitleSize: CGFloat = 13
    static let sectionHeaderSize: CGFloat = 18

    // Circular buttons — ButtonsTop 285:1346
    static let buttonDiameter: CGFloat = 48
    static let buttonShadowRadius: CGFloat = 2.967
    static let buttonShadowY: CGFloat = 3.68
    static let buttonShadowOpacity: CGFloat = 0.25

    // Blue glow — Ellipse 8
    static let glowWidth: CGFloat = 737
    static let glowHeight: CGFloat = 256
    static let glowOffsetY: CGFloat = 203
    static let glowOpacity: CGFloat = 0.28
    static let glowBlur: CGFloat = 50
}

// MARK: - Glass

extension View {
    /// Apple's real Liquid Glass on iOS 26 — the same material the sheet draws
    /// itself with, so the buttons and the sheet match by construction.
    @ViewBuilder
    func homeGlass(in shape: some InsettableShape, tint: Color = .clear) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background { GlassSurface(shape: shape, tint: tint) }
        }
    }
}

/// Fallback for systems without Liquid Glass.
struct GlassSurface<S: InsettableShape>: View {
    let shape: S
    var tint: Color = .clear

    var body: some View {
        shape
            .fill(.regularMaterial)
            .overlay { shape.fill(tint) }
            .overlay { shape.strokeBorder(SheetPalette.rimGradient, lineWidth: 1) }
    }
}

/// The circular buttons in the design (filter, profile, recenter, ✕).
///
/// The surface matters: over the map they are real Liquid Glass with the
/// design's drop shadow, but the same treatment *on* the sheet renders muddy
/// grey — glass inside glass cancels out, exactly as it did for the search
/// pill. On the sheet they take the pill's fill and rim instead, and no shadow
/// (the design gives the in-sheet ✕ none either).
struct GlassCircleButton<Label: View>: View {
    var surface: CircleButtonSurface = .overMap
    var diameter: CGFloat = SheetMetrics.buttonDiameter
    let action: () -> Void
    @ViewBuilder var label: Label

    var body: some View {
        Button(action: action) {
            label
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
                .modifier(CircleSurface(surface: surface))
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }
}

/// Where a circular button is drawn — glass behaves differently on each.
enum CircleButtonSurface { case overMap, onSheet }

private struct CircleSurface: ViewModifier {
    let surface: CircleButtonSurface

    func body(content: Content) -> some View {
        switch surface {
        case .overMap:
            content
                .homeGlass(in: Circle(), tint: .white.opacity(0.30))
                .shadow(
                    color: .black.opacity(SheetMetrics.buttonShadowOpacity),
                    radius: SheetMetrics.buttonShadowRadius,
                    y: SheetMetrics.buttonShadowY
                )
        case .onSheet:
            content
                .background(Circle().fill(Color(uiColor: .secondarySystemGroupedBackground)))
                .overlay(Circle().strokeBorder(SheetPalette.rimGradient, lineWidth: 1))
        }
    }
}



// MARK: - Search sheet

/// Content of the bottom sheet: a search field that expands the sheet when it
/// takes focus, category shortcuts before anything is typed, and live
// directory results once it is.
struct SearchSheet: View {
    /// Explicit state, never derived from the sheet's height — iOS resizes the
    /// sheet around the keyboard, and inferring intent from the detent made the
    /// content flip back mid-edit.
    @Binding var isExpanded: Bool
    @Binding var searchText: String
    /// Owned here, next to the TextField. It used to live in HomeMapView and be
    /// passed across the `.sheet` boundary — but @FocusState is scoped to the
    /// hierarchy that declares it, and a sheet is a separate presentation host,
    /// so focus changes were unreliable in both directions.
    @FocusState private var isFieldFocused: Bool
    /// Search is run by the shared MapModel behind this store; the sheet only shows its state.
    @ObservedObject var store: MapStore
    /// HomeMapView's pins, reused as the empty-query "Nearby" list. The sheet
    /// used to run its own search for the same region — every settled
    /// pan cost two identical nearby queries, and each re-presentation of the
    /// sheet (returning from a place page) cost another.
    let nearbyPlaces: [Place]
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            searchContent
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: searchText) { _, value in
            if !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isExpanded { isExpanded = true }
            store.queryChanged(value)
        }
        .onChange(of: isFieldFocused) { _, focused in
            // Taking focus is what opens the sheet.
            if focused, !isExpanded {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            // Only collapsing touches focus. Expanding deliberately does not:
            // dragging the grabber up should reveal the list without summoning
            // the keyboard, the way Apple Maps behaves. Tapping the field still
            // focuses it directly, which is what expands the sheet.
            if !expanded {
                isFieldFocused = false
            }
        }
    }

    // MARK: Layout

    private var searchContent: some View {
        VStack(spacing: 0) {
            grabber

            // The search row's structure never changes between states — only
            // values do.
            HStack(spacing: SheetMetrics.fieldSpacing) {
                searchField

                if isExpanded {
                    GlassCircleButton(surface: .onSheet) {
                        onCancelSearch()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, SheetMetrics.horizontalPadding)
            .padding(.top, SheetMetrics.rowTopPadding)
            .padding(.bottom, SheetMetrics.rowBottomPadding)

            // Always present, height-gated with smooth snappy transition.
            sheetBody
                .opacity(isExpanded ? 1 : 0)
                .frame(maxHeight: isExpanded ? .infinity : 0)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .animation(.snappy(duration: 0.28), value: isExpanded)
        .contentShape(Rectangle())
        .onTapGesture {
            if !isExpanded {
                withAnimation(.snappy(duration: 0.28)) {
                    isExpanded = true
                }
            } else {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        }
    }

    private var grabber: some View {
        Capsule()
            .fill(SheetPalette.grabber.opacity(isExpanded ? 0.5 : 0.65))
            .frame(width: SheetMetrics.grabberWidth, height: SheetMetrics.grabberHeight)
            .padding(.top, SheetMetrics.grabberTopPadding)
            .frame(maxWidth: .infinity, minHeight: SheetMetrics.grabberBlockHeight, alignment: .top)
    }

    private var searchField: some View {
        HStack(spacing: SheetMetrics.fieldSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary.opacity(SheetMetrics.textOpacity))

            ZStack(alignment: .leading) {
                if searchText.isEmpty {
                    // Static, as in the design (it used to cycle phrases).
                    Text("Search a place".localized)
                        .font(.system(size: SheetMetrics.textSize))
                        .tracking(SheetMetrics.textTracking)
                        .foregroundStyle(.primary.opacity(SheetMetrics.placeholderOpacity))
                        .allowsHitTesting(false)
                }

                TextField("", text: $searchText)
                    .font(.system(size: SheetMetrics.textSize))
                    .tracking(SheetMetrics.textTracking)
                    .foregroundStyle(.primary.opacity(SheetMetrics.textOpacity))
                    .tint(SheetPalette.brandBlue)
                    .focused($isFieldFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: SheetMetrics.fieldHeight)
        .background {
            Capsule().fill(Color(.systemBackground).opacity(isExpanded ? 1 : SheetMetrics.fieldFillOpacity))
        }
        .overlay {
            Capsule().strokeBorder(
                isExpanded ? AnyShapeStyle(SheetPalette.brandBlue) : AnyShapeStyle(SheetPalette.rimGradient),
                lineWidth: isExpanded ? SheetMetrics.fieldBorderWidth : 1
            )
        }
    }

    /// Malls of Bali before anything is typed, live API search results after.
    @ViewBuilder
    private var sheetBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SheetMetrics.rowSpacing) {
                // A one-letter query isn't a search yet (shared minimum length): keep showing Nearby.
                if !store.isSearchActive {
                    sectionHeader("Nearby Malls".localized)
                    if nearbyPlaces.isEmpty && store.hasLoadedOnce {
                        message("No places in this area yet. Move the map to explore.".localized)
                    } else if nearbyPlaces.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else {
                        ForEach(nearbyPlaces) { place in
                            resultRow(place, icon: "magnifyingglass")
                        }
                    }
                } else {
                    // Design order: recent places (clock), the "search nearby"
                    // action, then results (pin).
                    ForEach(store.recents) { place in
                        resultRow(place, icon: "clock.fill", iconColor: .secondary)
                    }
                    searchNearbyRow
                    if store.isSearching {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                    } else if let errorMessage = store.errorMessage {
                        message(errorMessage)
                    } else if store.results.isEmpty && store.recents.isEmpty {
                        message(String(format: "No places found for \"%@\" near here.".localized, query))
                    } else {
                        ForEach(store.results) { place in
                            resultRow(place, icon: "mappin")
                        }
                    }
                }
            }
            .padding(.horizontal, SheetMetrics.horizontalPadding)
            .padding(.bottom, 24)
        }
        .scrollDisabled(!isExpanded)
        .scrollDismissesKeyboard(.interactively)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: SheetMetrics.sectionHeaderSize, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.8))
            .padding(.bottom, SheetMetrics.rowSpacing)
    }

    /// "<query> · Search nearby": the design's action row. The results are already
    /// listed below, so it just puts the keyboard away to read them.
    private var searchNearbyRow: some View {
        Button {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SheetPalette.accentBlue)
                    .frame(width: SheetMetrics.rowIconWidth)
                VStack(alignment: .leading, spacing: 4) {
                    Text(query)
                        .font(.system(size: SheetMetrics.rowTitleSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text("Search nearby".localized)
                        .font(.system(size: SheetMetrics.rowSubtitleSize))
                        .foregroundStyle(.primary.opacity(0.7))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resultRow(_ place: Place, icon: String, iconColor: Color = SheetPalette.accentBlue) -> some View {
        Button {
            onSelectPlace(place)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(iconColor)
                    .frame(width: SheetMetrics.rowIconWidth)

                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.system(size: SheetMetrics.rowTitleSize, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let subtitle = subtitle(for: place) {
                        Text(subtitle)
                            .font(.system(size: SheetMetrics.rowSubtitleSize))
                            .foregroundStyle(.primary.opacity(0.7))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var card: some View {
        RoundedRectangle(cornerRadius: SheetMetrics.rowCornerRadius, style: .continuous)
            .fill(Color(uiColor: .secondarySystemGroupedBackground))
            .shadow(color: Color.black.opacity(0.04), radius: 3, x: 0, y: 1)
            .overlay {
                RoundedRectangle(cornerRadius: SheetMetrics.rowCornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            }
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)
            .padding(.vertical, 24)
    }

    private func subtitle(for place: Place) -> String? {
        let parts = [place.distance, place.address].filter { !$0.isEmpty }
        return parts.isEmpty ? (place.category.isEmpty ? nil : place.category)
                             : parts.joined(separator: " • ")
    }
}

