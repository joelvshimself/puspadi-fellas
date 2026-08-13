import MapKit
import SwiftUI

enum HomeTab: Hashable {
    case explore
    case saved
    case contribute
}

enum HomeRoute: Hashable {
    case place(Place)
    case saved
    case contribute
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
    @Binding var selectedTab: HomeTab
    var isSearchFocused: FocusState<Bool>.Binding
    let places: [Place]
    /// Biases MKLocalSearch toward what's currently on screen.
    let searchRegion: MKCoordinateRegion
    /// When set, the sheet shows this place's accessibility detail in place of
    /// the search UI (same-sheet method, no separate pushed page).
    @Binding var selectedPlace: Place?
    let onSelectPlace: (Place) -> Void
    let onCancelSearch: () -> Void
    let onSelectTab: (HomeTab) -> Void

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

    private let categories: [(symbol: String, label: String, query: String?)] = [
        ("fork.knife", "Food", "Restaurant"),
        ("building.2.fill", "Stay", "Hotel"),
        ("tree.fill", "Parks", "Park"),
        ("cup.and.saucer.fill", "Cafe", "Restaurant"),
        ("plus", "More", nil)
    ]

    private var results: [Place] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return query.isEmpty ? places : liveResults
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
                    Button("Cancel") {
                        onCancelSearch()
                    }
                    .font(.body)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)

            if isSearching {
                resultsList
                    .padding(.top, 8)
                    .transition(.opacity)
            } else {
                categoryRow
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))

                sheetTabBar
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
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
                    coordinate: item.placemark.coordinate
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

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            TextField("Find a place", text: $searchText)
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

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(categories, id: \.label) { item in
                    Button {
                        if let query = item.query {
                            searchText = query
                        }
                        beginSearch()
                    } label: {
                        Image(systemName: item.symbol)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(.primary)
                            .frame(width: 64, height: 64)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(item.label)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var sheetTabBar: some View {
        VStack(spacing: 0) {
            Divider()
                .padding(.horizontal, 8)

            HStack(spacing: 0) {
                tabItem(.explore, title: "Explore", systemName: "map.fill")
                tabItem(.saved, title: "Saved", systemName: "bookmark.fill")
                tabItem(.contribute, title: "Contribute", systemName: "plus.circle.fill")
            }
            .padding(.top, 10)
            .padding(.bottom, 4)
        }
    }

    private func tabItem(_ tab: HomeTab, title: String, systemName: String) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            VStack(spacing: 4) {
                Image(systemName: systemName)
                    .font(.system(size: 20, weight: .semibold))
                Text(title)
                    .font(.caption2.weight(.medium))
            }
            .foregroundStyle(selectedTab == tab ? Color.accentColor : .primary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private var isLiveQuery: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                Text(isLiveQuery ? "Results" : "Recent")
                    .font(.headline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                Divider()
                    .padding(.horizontal, 16)

                if isLiveQuery, isSearchingLive {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 24)
                } else if isLiveQuery, let searchErrorMessage {
                    statusMessage(searchErrorMessage)
                } else if isLiveQuery, results.isEmpty {
                    statusMessage("No places found for \"\(searchText)\" near here.")
                } else {
                    ForEach(results) { place in
                        Button {
                            onSelectPlace(place)
                        } label: {
                            resultRow(place)
                        }
                        .buttonStyle(.plain)

                        Divider()
                            .padding(.leading, 72)
                    }
                }
            }
            .padding(.bottom, 24)
        }
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

    private func resultRow(_ place: Place) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(place.accentColor.opacity(0.85))
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: place.gallerySymbols.first ?? "mappin")
                        .foregroundStyle(.white)
                        .font(.title3)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(place.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(place.distance.isEmpty ? place.category : "\(place.category) • \(place.distance)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    private func beginSearch() {
        detent = expandedDetent
        isSearchFocused.wrappedValue = true
    }
}

#Preview {
    struct PreviewHost: View {
        @State private var detent: PresentationDetent = .height(230)
        @State private var searchText = ""
        @State private var selectedTab: HomeTab = .explore
        @State private var selectedPlace: Place?
        @FocusState private var focused: Bool

        var body: some View {
            Color.gray.opacity(0.35).ignoresSafeArea()
                .sheet(isPresented: .constant(true)) {
                    SearchSheet(
                        detent: $detent,
                        searchText: $searchText,
                        selectedTab: $selectedTab,
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
                            detent = .height(230)
                        },
                        onSelectTab: { selectedTab = $0 }
                    )
                    .presentationDetents([peekDetent, expandedDetent], selection: $detent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .interactiveDismissDisabled()
                }
        }
    }

    return PreviewHost()
}
