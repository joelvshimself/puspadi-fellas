import MapKit
import SwiftUI

private let peekDetent: PresentationDetent = .height(230)

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

    private let places = Place.samples

    private var isSearching: Bool { sheetDetent == .large }

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
                        places: places,
                        searchRegion: visibleRegion,
                        selectedPlace: $selectedPlace,
                        onSelectPlace: openPlace,
                        onCancelSearch: dismissSearch,
                        onSelectTab: handleTabSelection
                    )
                    .presentationDetents([peekDetent, .large], selection: $sheetDetent)
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(24)
                    // Pin one opaque background across all detents. Without
                    // this, iOS renders the peek detent translucent (map shows
                    // through) and the full detent opaque, making the two
                    // states look like different screens.
                    .presentationBackground(Color(.systemBackground))
                    .interactiveDismissDisabled()
                }
                .onChange(of: isSearchFocused) { _, focused in
                    // TextField focus does not fire parent tap gestures; expand from focus.
                    if focused, !isSearching {
                        sheetDetent = .large
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
            ForEach(places) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(.red)
                        .background(
                            Circle()
                                .fill(.white)
                                .frame(width: 18, height: 18)
                        )
                }
            }
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
        sheetDetent = .large
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
