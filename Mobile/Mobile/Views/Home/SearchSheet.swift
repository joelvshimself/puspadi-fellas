import MapKit
import SwiftUI

enum HomeRoute: Hashable {
    case place(Place)
    case saved
    case contribute
}

/// Carries the measured search-bar row height up to HomeMapView so the peek
/// detent can be sized to the bar instead of a hardcoded value.
private struct PeekHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Content of the persistent bottom sheet presented by HomeMapView via a
/// real `.sheet(...) { }.presentationDetents(...)` — the same pattern
/// snackbud uses for its own sheets. That gives the native drag-up-to-expand
/// behavior and lets the map stay visible/interactive underneath at the
/// peek height, matching Google/Apple Maps rather than a hand-rolled
/// full-screen takeover.
struct SearchSheet: View {
    @Binding var detent: PresentationDetent
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    let places: [Place]
    /// Biases MKLocalSearch toward what's currently on screen.
    let searchRegion: MKCoordinateRegion
    /// When set, the sheet shows this place's accessibility detail in place of
    /// the search UI (same-sheet method, no separate pushed page).
    @Binding var selectedPlace: Place?
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void
    /// Reports the measured height of the search-bar row so the parent can size
    /// the peek detent to it exactly (equal padding, no hardcoded height).
    var onPeekHeightChange: (CGFloat) -> Void = { _ in }

    private var isSearching: Bool { detent == expandedDetent }

    /// Real on-device search results (MKLocalSearch) — replaces the old
    /// local substring filter over mock `places`. See §4.1 in
    /// docs/specs.md: MapKit resolves the query for free, on-device; only
    /// the resolved coordinate is ever sent to the backend, and only once
    /// the user taps a result (see PlaceDetailView).
    @State private var liveResults: [Place] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearchingLive = false
    @State private var searchErrorMessage: String?
    /// Recently opened places, persisted so the empty-search state can show a
    /// "Recent" section (clock rows) the way the design does.
    @AppStorage("recentSearches") private var recentsData = Data()

    /// Distinguishes the leading glyph on a result row (frames 4/5).
    private enum RowKind {
        case recent, suggestion, place
        var icon: String {
            switch self {
            case .recent: "clock"
            case .suggestion: "magnifyingglass"
            case .place: "mappin"
            }
        }
    }

    private struct RecentPlace: Codable, Identifiable {
        let name: String
        let address: String
        let lat: Double
        let lng: Double
        var id: String { "\(name)|\(lat)|\(lng)" }
        var place: Place {
            Place.fromSearchResult(
                name: name,
                category: "",
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng),
                address: address
            )
        }
    }

    private var recents: [RecentPlace] {
        (try? JSONDecoder().decode([RecentPlace].self, from: recentsData)) ?? []
    }

    private func recordRecent(_ place: Place) {
        let entry = RecentPlace(
            name: place.name,
            address: place.address,
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        var list = recents.filter { $0.id != entry.id }
        list.insert(entry, at: 0)
        list = Array(list.prefix(6))
        recentsData = (try? JSONEncoder().encode(list)) ?? recentsData
    }

    var body: some View {
        Group {
            if let selectedPlace {
                // Accessibility detail lives in the same sheet — tapping a
                // result swaps the sheet's content instead of pushing a page.
                PlaceDetailView(place: selectedPlace, onBack: { self.selectedPlace = nil })
            } else {
                searchContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onChange(of: searchText) { _, newValue in
            scheduleSearch(for: newValue)
        }
    }

    private var searchContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                searchField

                if isSearching {
                    // ✕ clear/close, matching the design (was a "Cancel" link).
                    Button {
                        onCancelSearch()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                            .background(Color.primary.opacity(0.06), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            // Equal padding all around the pill; the measured height of this
            // row is reported up so the peek detent fits it exactly.
            .padding(16)
            .background(
                GeometryReader { geo in
                    Color.clear.preference(key: PeekHeightKey.self, value: geo.size.height)
                }
            )

            // Clean home (frame 1): the peek is just the search pill. Category
            // tiles and the Explore/Saved/Contribute tab bar are gone — Saved
            // lives in the profile menu, Contribute on a place's detail.
            if isSearching {
                resultsList
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .onPreferenceChange(PeekHeightKey.self) { onPeekHeightChange($0) }
    }

    private func scheduleSearch(for query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            liveResults = []
            isSearchingLive = false
            searchErrorMessage = nil
            return
        }
        // Expand so results are actually visible. Driven by the text change
        // rather than field focus, because FocusState doesn't propagate
        // reliably across the sheet boundary (that's why results previously
        // only appeared after manually dragging the sheet up).
        if detent != expandedDetent {
            detent = expandedDetent
        }
        isSearchingLive = true
        searchErrorMessage = nil
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            await performSearch(trimmed)
        }
    }

    private func performSearch(_ query: String) async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.region = searchRegion
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard !Task.isCancelled else { return }
            liveResults = response.mapItems.map { item in
                Place.fromSearchResult(
                    name: item.name ?? query,
                    category: item.pointOfInterestCategory.map(categoryLabel) ?? "Place",
                    coordinate: item.placemark.coordinate,
                    address: shortAddress(item.placemark),
                    distance: distanceString(to: item.placemark.coordinate)
                )
            }
            isSearchingLive = false
        } catch {
            guard !Task.isCancelled else { return }
            // Surface this instead of silently showing an empty list — a
            // blank "Recent" list with no feedback reads as broken. Common
            // cause here is MKErrorDomain code 4 (placemark not found /
            // region has no matches), which is a normal "no results", not a
            // crash — but the user still needs to see *something* changed.
            liveResults = []
            isSearchingLive = false
            searchErrorMessage = (error as NSError).localizedDescription
        }
    }

    private func categoryLabel(for category: MKPointOfInterestCategory) -> String {
        category.rawValue.replacingOccurrences(of: "MKPOICategory", with: "")
    }

    /// A concise "123 Main St · Neighborhood" line from a placemark for the
    /// result subtitle.
    private func shortAddress(_ placemark: MKPlacemark) -> String {
        let street = [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap { $0 }
            .joined(separator: " ")
        return [street, placemark.locality ?? ""]
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }

    /// Rough distance from the current map center (a stand-in for the user's
    /// location) to a result, formatted for the subtitle.
    private func distanceString(to coordinate: CLLocationCoordinate2D) -> String {
        let center = CLLocation(latitude: searchRegion.center.latitude,
                                longitude: searchRegion.center.longitude)
        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let miles = center.distance(from: target) / 1609.34
        if miles < 0.1 { return "Nearby" }
        return String(format: "%.1f mi", miles)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Search a place", text: $searchText)
                .focused(isSearchFocused)
                .textInputAutocapitalization(.never)
                .submitLabel(.search)

            Image(systemName: "mic.fill")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.06))
        )
    }

    private var isLiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 10) {
                if isLiveQuery {
                    sectionHeader("Results")
                    if isSearchingLive {
                        ProgressView()
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if let searchErrorMessage {
                        statusMessage(searchErrorMessage)
                    } else if liveResults.isEmpty {
                        statusMessage("No places found for \"\(searchText)\" near here.")
                    } else {
                        ForEach(liveResults) { place in
                            row(place, kind: .suggestion)
                        }
                    }
                } else {
                    if !recents.isEmpty {
                        sectionHeader("Recent")
                        ForEach(recents) { recent in
                            row(recent.place, kind: .recent)
                        }
                    }
                    sectionHeader("Nearby")
                    ForEach(places) { place in
                        row(place, kind: .suggestion)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.top, 12)
            .padding(.bottom, 2)
    }

    @ViewBuilder
    private func row(_ place: Place, kind: RowKind) -> some View {
        Button {
            recordRecent(place)
            onSelectPlace(place)
        } label: {
            resultRow(place, kind: kind)
        }
        .buttonStyle(.plain)
    }

    private func statusMessage(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 24)
            .padding(.vertical, 24)
            .multilineTextAlignment(.center)
    }

    private func resultRow(_ place: Place, kind: RowKind) -> some View {
        HStack(spacing: 14) {
            Image(systemName: kind.icon)
                .font(.system(size: 18, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(place.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                if let subtitle = rowSubtitle(place) {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color(.systemBackground).opacity(0.7), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }

    /// "0.4 mi · Market St · Downtown" — distance and address joined, falling
    /// back to the category when neither is known.
    private func rowSubtitle(_ place: Place) -> String? {
        let parts = [place.distance, place.address].filter { !$0.isEmpty }
        if parts.isEmpty {
            return place.category.isEmpty ? nil : place.category
        }
        return parts.joined(separator: " • ")
    }

}

#Preview {
    struct PreviewHost: View {
        // Preview-only literal; the app derives this from the measured bar.
        @State private var detent: PresentationDetent = .height(92)
        @State private var searchText = ""
        @State private var selectedPlace: Place?
        @FocusState private var focused: Bool

        var body: some View {
            Color.gray.opacity(0.35).ignoresSafeArea()
                .sheet(isPresented: .constant(true)) {
                    SearchSheet(
                        detent: $detent,
                        searchText: $searchText,
                        isSearchFocused: $focused,
                        places: Place.samples,
                        searchRegion: MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
                            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
                        ),
                        selectedPlace: $selectedPlace,
                        onSelectPlace: { _ in },
                        onCancelSearch: {
                            focused = false
                            searchText = ""
                            detent = .height(92)
                        }
                    )
                    .presentationDetents([.height(92), expandedDetent], selection: $detent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                }
        }
    }

    return PreviewHost()
}
