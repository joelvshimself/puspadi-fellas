import MapKit
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
    static let grabberTopPadding: CGFloat = 8
    static let grabberBlockHeight: CGFloat = 16

    /// These two must still sum with the grabber and field to 102pt — that is
    /// the detent floor below which iOS squeezes the sheet's contents. To
    /// tighten the gap under the pill, move points from bottom to top.
    static let rowTopPadding: CGFloat = 20
    static let rowBottomPadding: CGFloat = 10
    static let horizontalPadding: CGFloat = 16

    static let fieldHeight: CGFloat = 56
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
/// MKLocalSearch results once it is.
struct SearchSheet: View {
    /// Explicit state, never derived from the sheet's height — iOS resizes the
    /// sheet around the keyboard, and inferring intent from the detent made the
    /// content flip back mid-edit.
    @EnvironmentObject private var languageManager: LanguageManager
    @Binding var isExpanded: Bool
    @Binding var searchText: String
    /// Owned here, next to the TextField. It used to live in HomeMapView and be
    /// passed across the `.sheet` boundary — but @FocusState is scoped to the
    /// hierarchy that declares it, and a sheet is a separate presentation host,
    /// so focus changes were unreliable in both directions.
    @FocusState private var isFieldFocused: Bool
    let searchRegion: MKCoordinateRegion
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void

    @StateObject private var speechRecognizer = SpeechRecognizer()
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
            // Taking focus is what opens the sheet.
            if focused, !isExpanded {
                withAnimation(.easeInOut(duration: 0.25)) { isExpanded = true }
            }
        }
        .onChange(of: isExpanded) { _, expanded in
            isFieldFocused = expanded
            if !expanded {
                speechRecognizer.stopListening()
            }
        }
        .onDisappear {
            speechRecognizer.stopListening()
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
                        speechRecognizer.stopListening()
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
                    TypewriterPlaceholderView()
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

            Button {
                if !isExpanded {
                    withAnimation(.snappy(duration: 0.28)) {
                        isExpanded = true
                    }
                }
                speechRecognizer.updateLanguage(languageIdentifier: languageManager.currentLanguage == .indonesia ? "id-ID" : "en-US")
                speechRecognizer.toggleListening { recognizedText in
                    searchText = recognizedText
                }
            } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(speechRecognizer.isListening ? Color.red : .secondary)
                    .scaleEffect(speechRecognizer.isListening ? 1.15 : 1.0)
                    .animation(speechRecognizer.isListening ? .easeInOut(duration: 0.6).repeatForever(autoreverses: true) : .default, value: speechRecognizer.isListening)
                    .frame(width: SheetMetrics.rowIconWidth)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .frame(height: SheetMetrics.fieldHeight)
        .background {
            Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground))
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
                if query.isEmpty {
                    sectionHeader("Malls of Bali".localized)
                    ForEach(Place.baliMalls) { place in
                        resultRow(place)
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
        .scrollDisabled(!isExpanded)
        .scrollDismissesKeyboard(.interactively)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: SheetMetrics.sectionHeaderSize, weight: .semibold))
            .foregroundStyle(.primary.opacity(0.8))
            .padding(.bottom, SheetMetrics.rowSpacing)
    }

    private func resultRow(_ place: Place) -> some View {
        Button {
            speechRecognizer.stopListening()
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

        if !isExpanded { isExpanded = true }
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

// MARK: - Typewriter Placeholder

/// Animated typewriter placeholder for search bar with rotating suggestions.
struct TypewriterPlaceholderView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    private let englishPhrases: [String] = [
        "Search a place...",
        "Search Malls in Bali...",
        "Find Beachwalk, Level 21...",
        "Discover accessible spots...",
        "Search shopping centers..."
    ]

    private let indonesianPhrases: [String] = [
        "Cari tempat...",
        "Cari Mall di Bali...",
        "Temukan Beachwalk, Level 21...",
        "Cari tempat aksesibel...",
        "Cari pusat perbelanjaan..."
    ]

    private var phrases: [String] {
        languageManager.currentLanguage == .indonesia ? indonesianPhrases : englishPhrases
    }

    @State private var displayedText: String = ""
    @State private var phraseIndex: Int = 0
    @State private var charIndex: Int = 0
    @State private var isDeleting: Bool = false
    @State private var timer: Timer? = nil

    var body: some View {
        HStack(spacing: 0) {
            Text(displayedText)
                .font(.system(size: SheetMetrics.textSize))
                .foregroundStyle(.secondary.opacity(0.65))
            Spacer()
        }
        .allowsHitTesting(false)
        .onAppear { startTyping() }
        .onDisappear { stopTyping() }
        .onChange(of: languageManager.currentLanguage) { _, _ in
            phraseIndex = 0
            charIndex = 0
            isDeleting = false
            displayedText = ""
            startTyping()
        }
    }

    private func startTyping() {
        stopTyping()
        stepAnimation()
    }

    private func stopTyping() {
        timer?.invalidate()
        timer = nil
    }

    private func stepAnimation() {
        let currentPhrases = phrases
        guard !currentPhrases.isEmpty else { return }
        let targetPhrase = currentPhrases[phraseIndex % currentPhrases.count]

        if !isDeleting {
            if charIndex < targetPhrase.count {
                charIndex += 1
                let index = targetPhrase.index(targetPhrase.startIndex, offsetBy: charIndex)
                displayedText = String(targetPhrase[..<index])
                timer = Timer.scheduledTimer(withTimeInterval: 0.07, repeats: false) { _ in
                    stepAnimation()
                }
            } else {
                timer = Timer.scheduledTimer(withTimeInterval: 2.2, repeats: false) { _ in
                    isDeleting = true
                    stepAnimation()
                }
            }
        } else {
            if charIndex > 0 {
                charIndex -= 1
                let index = targetPhrase.index(targetPhrase.startIndex, offsetBy: charIndex)
                displayedText = String(targetPhrase[..<index])
                timer = Timer.scheduledTimer(withTimeInterval: 0.035, repeats: false) { _ in
                    stepAnimation()
                }
            } else {
                isDeleting = false
                phraseIndex = (phraseIndex + 1) % currentPhrases.count
                timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: false) { _ in
                    stepAnimation()
                }
            }
        }
    }
}
