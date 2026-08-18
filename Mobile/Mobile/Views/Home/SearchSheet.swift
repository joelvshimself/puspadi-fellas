import MapKit
import SwiftUI

enum HomeRoute: Hashable {
    case place(Place)
    case saved
    case contribute
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
        colors: [.primary.opacity(0.06), .primary.opacity(0.16)],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum SheetMetrics {
    // Peek — Homepage 285:1323
    static let grabberWidth: CGFloat = 48
    static let grabberHeight: CGFloat = 6
    static let grabberTopPadding: CGFloat = 18
    static let grabberBlockHeight: CGFloat = 16

    /// These two must still sum with the grabber and field to 102pt — that is
    /// the detent floor below which iOS squeezes the sheet's contents. To
    /// tighten the gap under the pill, move points from bottom to top.
    /// NOTE: grabber + this + fieldHeight + rowBottomPadding must stay >= 102.
    /// That is a hard floor: iOS squeezes a sheet below it instead of honouring
    /// the detent. Measured — at 98 the sheet renders 87pt, at 92 it renders
    /// 84pt, both shorter than asked for, with the 6pt grabber crushed to
    /// nothing. Shrinking the peek means shrinking the field, not the padding.
    static let rowTopPadding: CGFloat = 20
    static let rowBottomPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 16

    static let fieldHeight: CGFloat = 46
    static let fieldSpacing: CGFloat = 8
    static let fieldFillOpacity: CGFloat = 0.8
    static let fieldBorderWidth: CGFloat = 2

    static let textSize: CGFloat = 17
    static let textTracking: CGFloat = -0.43
    static let textOpacity: CGFloat = 0.8
    static let placeholderOpacity: CGFloat = 0.3

    /// 102pt is a hard floor for the detent: below it iOS squeezes the sheet's
    /// contents to fit (at 92 the 6pt grabber renders 2pt and vanishes).
    static let peekHeight: CGFloat =
        grabberBlockHeight + rowTopPadding + fieldHeight + rowBottomPadding

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
                .modifier(CircleSurface(surface: surface))
        }
        .buttonStyle(.plain)
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
                .background(Circle().fill(Color(.systemBackground)))
                .overlay(Circle().strokeBorder(SheetPalette.rimGradient, lineWidth: 1))
        }
    }
}

// MARK: - Categories

/// The Apple-Maps-style shortcuts shown before anything is typed.
enum SearchCategory: String, CaseIterable, Identifiable {
    case malls, restaurants, cafes, parks, hotels, transit

    var id: String { rawValue }

    var label: String {
        switch self {
        case .malls: "Malls"
        case .restaurants: "Restaurants"
        case .cafes: "Cafes"
        case .parks: "Parks"
        case .hotels: "Hotels"
        case .transit: "Transit"
        }
    }

    var icon: String {
        switch self {
        case .malls: "bag.fill"
        case .restaurants: "fork.knife"
        case .cafes: "cup.and.saucer.fill"
        case .parks: "tree.fill"
        case .hotels: "bed.double.fill"
        case .transit: "tram.fill"
        }
    }
}

// MARK: - Search sheet

/// Content of the bottom sheet: a search field that expands the sheet when it
/// takes focus, category shortcuts before anything is typed, and live
/// MKLocalSearch results once it is.
struct SearchSheet: View {
    /// Whether the sheet is tall enough to show the list. Purely a height
    /// question — Apple Maps reveals its list as the sheet grows, whether or
    /// not you are editing.
    let showsResults: Bool

    /// Whether the field is being edited. Deliberately NOT the sheet's height:
    /// Apple Maps lets you drag to full height with no keyboard. Keeping the
    /// two apart is what stops a keyboard-driven resize from changing the
    /// field's appearance or focus.
    @Binding var isEditing: Bool
    @Binding var searchText: String
    /// Owned here, next to the TextField. It used to live in HomeMapView and be
    /// passed across the `.sheet` boundary — but @FocusState is scoped to the
    /// hierarchy that declares it, and a sheet is a separate presentation host,
    /// so focus changes were unreliable in both directions.
    @FocusState private var isFieldFocused: Bool
    let searchRegion: MKCoordinateRegion
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void

    @State private var results: [Place] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?

    private var query: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        Group {
            searchContent
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: searchText) { _, value in scheduleSearch(for: value) }
        .onChange(of: isFieldFocused) { _, focused in
            if focused != isEditing { isEditing = focused }
        }
        .onChange(of: isEditing) { _, editing in
            // Only ✕ / cancel drives this from outside; dragging never does.
            if !editing { isFieldFocused = false }
        }
    }

    // MARK: Layout

    private var searchContent: some View {
        VStack(spacing: 0) {
            grabber

            // The search row's structure never changes between states — only
            // values do. An `if` around this subtree would give it a new
            // identity, tearing down the TextField and dropping keystrokes.
            HStack(spacing: SheetMetrics.fieldSpacing) {
                searchField

                GlassCircleButton(surface: .onSheet, action: onCancelSearch) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                }
                .frame(width: isEditing ? SheetMetrics.buttonDiameter : 0)
                .opacity(isEditing ? 1 : 0)
                .clipped()
            }
            .padding(.horizontal, SheetMetrics.horizontalPadding)
            .padding(.top, SheetMetrics.rowTopPadding)
            .padding(.bottom, SheetMetrics.rowBottomPadding)

            // Revealed as the sheet grows, like Apple Maps — never gated on
            // editing, so dragging and tapping cannot disagree. Hidden at the
            // peek height, where its section header would otherwise show
            // through the home-indicator strip under the search field.
            sheetBody
                .opacity(showsResults ? 1 : 0)
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    private var grabber: some View {
        Capsule()
            .fill(SheetPalette.grabber.opacity(isEditing ? 0.5 : 0.65))
            .frame(width: SheetMetrics.grabberWidth, height: SheetMetrics.grabberHeight)
            .padding(.top, SheetMetrics.grabberTopPadding)
            .frame(maxWidth: .infinity, minHeight: SheetMetrics.grabberBlockHeight, alignment: .top)
    }

    private var searchField: some View {
        HStack(spacing: SheetMetrics.fieldSpacing) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary.opacity(SheetMetrics.textOpacity))

            TextField("Search a place", text: $searchText)
                .font(.system(size: SheetMetrics.textSize))
                .tracking(SheetMetrics.textTracking)
                .foregroundStyle(.primary.opacity(SheetMetrics.textOpacity))
                .tint(SheetPalette.brandBlue)
                .focused($isFieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            // The design names this microphone.fill, which is the SF Symbols
            // 2024 rename and needs iOS 18; mic.fill is the same glyph and works
            // on the project's iOS 17 deployment target.
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: SheetMetrics.rowIconWidth)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 12)
        .frame(height: SheetMetrics.fieldHeight)
        .background {
            Capsule().fill(Color(.systemBackground).opacity(isEditing ? 1 : SheetMetrics.fieldFillOpacity))
        }
        .overlay {
            Capsule().strokeBorder(
                isEditing ? AnyShapeStyle(SheetPalette.brandBlue) : AnyShapeStyle(SheetPalette.rimGradient),
                lineWidth: isEditing ? SheetMetrics.fieldBorderWidth : 1
            )
        }
    }

    /// Categories before anything is typed, results after.
    @ViewBuilder
    private var sheetBody: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: SheetMetrics.rowSpacing) {
                if query.isEmpty {
                    sectionHeader("Find nearby accessible spots")
                    ForEach(SearchCategory.allCases) { category in
                        categoryRow(category)
                    }
                } else if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else if let errorMessage {
                    message(errorMessage)
                } else if results.isEmpty {
                    message("No places found for \"\(query)\" near here.")
                } else {
                    ForEach(results) { place in
                        resultRow(place)
                    }
                }
            }
            .padding(.horizontal, SheetMetrics.horizontalPadding)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: SheetMetrics.sectionHeaderSize))
            .foregroundStyle(.primary.opacity(0.7))
            .padding(.bottom, SheetMetrics.rowSpacing)
    }

    private func categoryRow(_ category: SearchCategory) -> some View {
        Button {
            searchText = category.label
        } label: {
            HStack(spacing: 16) {
                Image(systemName: category.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SheetPalette.accentBlue)
                    .frame(width: SheetMetrics.rowIconWidth)

                Text(category.label)
                    .font(.system(size: SheetMetrics.rowTitleSize, weight: .semibold))
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(card)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func resultRow(_ place: Place) -> some View {
        Button {
            onSelectPlace(place)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "mappin.circle.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(SheetPalette.accentBlue)
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
            .fill(Color(.systemBackground).opacity(SheetMetrics.fieldFillOpacity))
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

    // MARK: Search

    private func scheduleSearch(for text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty else {
            results = []
            isLoading = false
            errorMessage = nil
            return
        }

        if !isEditing { isEditing = true }
        isLoading = true
        errorMessage = nil

        searchTask = Task {
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ text: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = text
        request.region = searchRegion

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            results = response.mapItems.map { item in
                Place.fromSearchResult(
                    name: item.name ?? text,
                    category: item.pointOfInterestCategory?.rawValue
                        .replacingOccurrences(of: "MKPOICategory", with: "") ?? "Place",
                    coordinate: item.placemark.coordinate,
                    address: shortAddress(item.placemark),
                    distance: distance(to: item.placemark.coordinate)
                )
            }
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
            // MKErrorDomain code 4 is a normal "no matches here", not a crash,
            // but the user still needs to see that something changed.
            results = []
            isLoading = false
            errorMessage = (error as NSError).localizedDescription
        }
    }

    private func shortAddress(_ placemark: MKPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        return [street, placemark.locality ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    private func distance(to coordinate: CLLocationCoordinate2D) -> String {
        let from = CLLocation(latitude: searchRegion.center.latitude,
                              longitude: searchRegion.center.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let metres = from.distance(from: to)
        return metres < 1000 ? "\(Int(metres)) m"
                             : String(format: "%.1f km", metres / 1000)
    }
}
