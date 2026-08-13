import MapKit
import SwiftUI

let peekDetent: PresentationDetent = .height(230)
/// A tall CUSTOM detent instead of .large: iOS gives the true .large detent an
/// opaque background, but custom/medium detents keep the translucent Liquid
/// Glass treatment — so the expanded sheet stays glassy like the peek.
let expandedDetent: PresentationDetent = .fraction(0.92)

struct HomeMapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
    )
    /// Tracked separately from `cameraPosition` (which is opaque) so
    /// SearchSheet has a plain MKCoordinateRegion to bias MKLocalSearch
    /// toward what's currently on screen.
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
    )
    /// A persistent, draggable bottom sheet (native .sheet + presentationDetents,
    /// same pattern snackbud uses elsewhere) instead of a view that swaps its
    /// own frame/background — this is what gives the real drag-up-to-expand,
    /// map-stays-interactive-underneath feel of Google/Apple Maps.
    @State private var isSheetPresented = true
    @State private var sheetDetent: PresentationDetent = peekDetent
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab: HomeTab = .explore
    @State private var showAnalysing = false
    @State private var path = NavigationPath()
    @StateObject private var locationManager = LocationManager()
    /// So the very first real location fix recenters the map once, without
    /// fighting the user if they've already panned elsewhere themselves.
    @State private var hasCenteredOnUser = false
    /// Lets the user tap a place/POI on the map (Google-Maps-style) to open
    /// its accessibility detail — without this the map is view-only.
    /// MapFeature (not MapSelection, which is iOS 18+) so this works on the
    /// project's iOS 17 deployment target.
    @State private var mapSelection: MapFeature?
    /// The place whose accessibility detail is shown inside the bottom sheet
    /// (same-sheet method — no separate pushed page).
    @State private var selectedPlace: Place?


    private var isSearching: Bool { sheetDetent == expandedDetent }

    var body: some View {
        NavigationStack(path: $path) {
            mapLayer
                .ignoresSafeArea()
                .overlay(alignment: .top) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .overlay(alignment: .bottomTrailing) {
                    locationButton
                        .padding(.trailing, 16)
                        .padding(.bottom, 16)
                }
                .toolbar(path.isEmpty ? .hidden : .automatic, for: .navigationBar)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .place:
                        // Place detail now renders inside the sheet, not here.
                        EmptyView()
                    case .saved:
                        SavedView()
                    case .contribute:
                        ContributeView()
                    }
                }
                .fullScreenCover(isPresented: $showAnalysing) {
                    AnalysingView(onDismiss: { showAnalysing = false })
                }
                .sheet(isPresented: $isSheetPresented) {
                    SearchSheet(
                        detent: $sheetDetent,
                        searchText: $searchText,
                        selectedTab: $selectedTab,
                        isSearchFocused: $isSearchFocused,
                        searchRegion: visibleRegion,
                        selectedPlace: $selectedPlace,
                        onSelectPlace: openPlace,
                        onCancelSearch: dismissSearch,
                        onSelectTab: handleTabSelection
                    )
                    // While a place detail is showing, lock the sheet to the
                    // expanded detent — collapsing detail content to the 230pt
                    // peek cut it into an ugly sliver. Search/browse keeps both.
                    .presentationDetents(
                        selectedPlace == nil ? [peekDetent, expandedDetent] : [expandedDetent],
                        selection: $sheetDetent
                    )
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    // No explicit presentationBackground — the iOS 26 default
                    // sheet is Liquid Glass (translucent, map shows through).
                    // An explicit material override flattened it to gray.
                    .interactiveDismissDisabled()
                }
                .onChange(of: isSearchFocused) { _, focused in
                    // TextField focus does not fire parent tap gestures; expand from focus.
                    if focused, !isSearching {
                        sheetDetent = expandedDetent
                    }
                }
                .onChange(of: path.count) { _, count in
                    if count == 0 {
                        // Back at the map root — bring the search sheet back
                        // at its peek height.
                        selectedTab = .explore
                        sheetDetent = peekDetent
                        isSheetPresented = true
                    } else {
                        // Navigated into a pushed destination (place detail,
                        // saved, contribute). The sheet is presented modally
                        // above the whole NavigationStack, so it would
                        // otherwise float on top of the pushed page — dismiss
                        // it while we're deeper in the stack.
                        isSheetPresented = false
                    }
                }
                .onChange(of: selectedPlace) { _, place in
                    // Opening a place (from a result or a map POI tap) always
                    // expands the sheet so the detail isn't shown cramped at
                    // peek height.
                    if place != nil { sheetDetent = expandedDetent }
                }
                .onChange(of: locationManager.currentCoordinate) { _, coordinate in
                    guard let coordinate, !hasCenteredOnUser else { return }
                    hasCenteredOnUser = true
                    recenter(on: coordinate.clLocation)
                }
                .task {
                    locationManager.requestLocation()
                }
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, selection: $mapSelection) {
            
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
        }
        .mapStyle(.standard(elevation: .realistic))
        .onChange(of: mapSelection) { _, selection in
            handleMapSelection(selection)
        }
    }

    /// A tapped map POI carries a name + coordinate — exactly what the
    /// accessibility pipeline needs — so route it through the same
    /// openPlace() path a search-result tap uses.
    private func handleMapSelection(_ feature: MapFeature?) {
        guard let feature else { return }
        mapSelection = nil
        openPlace(
            Place.fromSearchResult(
                name: feature.title ?? "Selected place",
                category: "Place",
                coordinate: feature.coordinate
            )
        )
    }

    private var topBar: some View {
        HStack {
            circularButton(systemName: "line.3.horizontal.decrease") {}

            Spacer()

            circularButton(systemName: "person.fill") {}
                .onLongPressGesture(minimumDuration: 0.5) {
                    showAnalysing = true
                }
                .accessibilityHint("Long press to open Analysing demo")
        }
    }

    private var locationButton: some View {
        Button {
            if let coordinate = locationManager.currentCoordinate {
                recenter(on: coordinate.clLocation, span: 0.04)
            } else {
                locationManager.requestLocation()
            }
        } label: {
            Image(systemName: "location")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("My location")
    }

    private func circularButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func recenter(on coordinate: CLLocationCoordinate2D, span: Double = 0.08) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
        visibleRegion = region
    }

    private func dismissSearch() {
        isSearchFocused = false
        searchText = ""
        sheetDetent = peekDetent
    }

    private func openPlace(_ place: Place) {
        // Show the accessibility detail inside the sheet (not a pushed page),
        // and expand the sheet so it's fully visible.
        isSearchFocused = false
        selectedPlace = place
        sheetDetent = expandedDetent
    }

    private func handleTabSelection(_ tab: HomeTab) {
        selectedTab = tab
        switch tab {
        case .explore:
            break
        case .saved:
            path.append(HomeRoute.saved)
        case .contribute:
            path.append(HomeRoute.contribute)
        }
    }
}

#Preview {
    HomeMapView()
}
