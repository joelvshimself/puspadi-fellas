import MapKit
import SwiftUI

// The system drag indicator is drawn over the top of the sheet content and
// fits inside the search bar's own top padding, so no extra height is needed
// for it — the peek detent is just the measured bar. (The sheet always adds
// the bottom home-indicator safe-area strip on top of this.)
private let grabberInset: CGFloat = 0
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
    /// Measured height of the search-bar row (reported by SearchSheet). The
    /// peek detent is derived from this so it fits the bar exactly instead of
    /// a hardcoded value. Seeded with a sane fallback for the first layout
    /// pass, then corrected once the bar reports its real size.
    @State private var peekBarHeight: CGFloat = 68
    @State private var sheetDetent: PresentationDetent = .height(68 + 24)
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
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
    /// Accessibility grades the user is filtering the map to. Empty = show all
    /// (no filter). See the filter panel opened from the top-left button.
    @State private var selectedGrades: Set<OverallAccessibility> = []
    @State private var showFilter = false
    /// Bottom safe-area height, captured before the map ignores safe areas, so
    /// the location button can be floated just above the peek sheet.
    @State private var bottomSafeInset: CGFloat = 34

    private let places = Place.samples

    private var isSearching: Bool { sheetDetent == expandedDetent }

    /// Pins shown on the map — narrowed to the selected grades when the filter
    /// is active. Ungraded places drop out while any filter is on.
    private var filteredPlaces: [Place] {
        guard !selectedGrades.isEmpty else { return places }
        return places.filter { place in
            guard let grade = place.grade else { return false }
            return selectedGrades.contains(grade)
        }
    }

    /// The peek detent, sized to the measured search bar plus the system drag
    /// handle — no hardcoded sheet height.
    private var peekDetent: PresentationDetent { .height(peekBarHeight + grabberInset) }

    var body: some View {
        NavigationStack(path: $path) {
            mapLayer
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .onAppear { bottomSafeInset = proxy.safeAreaInsets.bottom }
                            .onChange(of: proxy.safeAreaInsets.bottom) { _, value in
                                bottomSafeInset = value
                            }
                    }
                )
                .ignoresSafeArea()
                // Dim the map while the filter panel is open (frame 2).
                .overlay {
                    if showFilter {
                        Color.black.opacity(0.4)
                            .ignoresSafeArea()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                                    showFilter = false
                                }
                            }
                            .transition(.opacity)
                    }
                }
                .overlay(alignment: .top) {
                    topBar
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                }
                .overlay(alignment: .topLeading) {
                    if showFilter {
                        // Options fan out to the right of the filter button,
                        // first row aligned with it (matches the mockup).
                        filterPanel
                            .padding(.leading, 72)
                            .padding(.top, 8)
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    // Floated just above the peek sheet (which otherwise covers
                    // the screen bottom). Hidden while searching or filtering.
                    if !isSearching && !showFilter {
                        locationButton
                            .padding(.trailing, 16)
                            .padding(.bottom, peekBarHeight + bottomSafeInset + 12)
                            .transition(.opacity)
                    }
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
                        isSearchFocused: $isSearchFocused,
                        places: places,
                        searchRegion: visibleRegion,
                        selectedPlace: $selectedPlace,
                        onSelectPlace: openPlace,
                        onCancelSearch: dismissSearch,
                        onPeekHeightChange: { height in
                            guard height > 0, abs(height - peekBarHeight) > 0.5 else { return }
                            peekBarHeight = height
                        }
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
                .onChange(of: peekBarHeight) { _, _ in
                    // The peek detent's value just changed, so the old value
                    // is no longer in the detents set. If we're sitting at the
                    // peek, re-point the selection at the new one so the sheet
                    // doesn't snap to a fallback detent.
                    if sheetDetent != expandedDetent {
                        sheetDetent = peekDetent
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
            // The blue "current location" dot (with heading) — this is the
            // person's own position pin.
            UserAnnotation()

            ForEach(filteredPlaces) { place in
                Annotation(place.name, coordinate: place.coordinate) {
                    Image(systemName: "mappin.circle.fill")
                        .font(.title)
                        .foregroundStyle(place.grade?.color ?? .red)
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
            circularButton(systemName: "line.3.horizontal.decrease") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showFilter.toggle()
                }
            }
            .overlay(alignment: .topTrailing) {
                if !selectedGrades.isEmpty {
                    Text("\(selectedGrades.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 20, minHeight: 20)
                        .background(Circle().fill(Color.accentColor))
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .offset(x: 6, y: -6)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()

            // Profile button opens Saved (the home tab bar was removed in the
            // redesign; Saved lives here, Contribute is on a place's detail).
            circularButton(systemName: "person.fill") {
                path.append(HomeRoute.saved)
            }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showAnalysing = true
                }
                .accessibilityHint("Long press to open Analysing demo")
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(OverallAccessibility.allCases) { grade in
                let isOn = selectedGrades.contains(grade)
                Button {
                    toggleGrade(grade)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: grade.symbolName)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                            .frame(width: 44, height: 44)
                            .background {
                                if isOn {
                                    Circle().fill(grade.color)
                                } else {
                                    Circle().fill(.ultraThinMaterial)
                                }
                            }
                            .shadow(color: .black.opacity(0.12), radius: 8, y: 2)

                        Text(grade.label)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func toggleGrade(_ grade: OverallAccessibility) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if selectedGrades.contains(grade) {
                selectedGrades.remove(grade)
            } else {
                selectedGrades.insert(grade)
            }
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

}

#Preview {
    HomeMapView()
}
