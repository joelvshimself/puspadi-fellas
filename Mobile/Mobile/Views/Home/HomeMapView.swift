import MapKit
import SwiftUI

/// A tall CUSTOM detent instead of .large: iOS gives the true .large detent an
/// opaque background, but custom/medium detents keep the translucent Liquid
/// Glass treatment — so the expanded sheet stays glassy like the peek.
/// The tallest a floating glass sheet will go. The design puts the focused
/// sheet's top edge at 60pt, but iOS clamps a non-`.large` sheet to ~715pt
/// here (both `.fraction(0.98)` and `.height(777)` land at the ceiling), and
/// `.large` is the wrong look — it turns opaque and anchors to the screen
/// edges instead of floating.
let expandedDetent: PresentationDetent = .fraction(0.98)

/// Initial and recenter zoom. Roughly a 1.3km span — close enough to read
/// street names, like Apple Maps opens.
let defaultMapSpan: Double = 0.012

struct HomeMapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
            span: MKCoordinateSpan(latitudeDelta: defaultMapSpan, longitudeDelta: defaultMapSpan)
        )
    )
    /// Tracked separately from `cameraPosition` (which is opaque) so
    /// SearchSheet has a plain MKCoordinateRegion to bias MKLocalSearch
    /// toward what's currently on screen.
    @State private var visibleRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194),
        span: MKCoordinateSpan(latitudeDelta: defaultMapSpan, longitudeDelta: defaultMapSpan)
    )
    /// A persistent, draggable bottom sheet (native .sheet + presentationDetents,
    /// same pattern snackbud uses elsewhere) instead of a view that swaps its
    /// own frame/background — this is what gives the real drag-up-to-expand,
    /// map-stays-interactive-underneath feel of Google/Apple Maps.
    @State private var isSheetPresented = true
    @State private var sheetDetent: PresentationDetent = .height(SheetMetrics.peekHeight)
    /// The single source of truth for "the user is searching". Kept separate
    /// from `sheetDetent` because iOS resizes the sheet around the keyboard;
    /// deriving this from the detent made the sheet flip between its collapsed
    /// and expanded looks while typing.
    @State private var isSearchActive = false
    @State private var searchText = ""
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
    /// The sheet detent in effect just before a place detail was opened, so
    /// closing the detail returns to that step (peek if the place came from a
    /// map tap, the expanded search list if it came from a result).
    /// Accessibility grades the user is filtering the map to. Empty = show all
    /// (no filter). See the filter panel opened from the top-left button.
    @State private var selectedGrades: Set<OverallAccessibility> = []
    @State private var showFilter = false
    /// Bottom safe-area height, captured before the map ignores safe areas, so
    /// the location button can be floated just above the peek sheet.
    @State private var bottomSafeInset: CGFloat = 34


    private var isSearching: Bool { isSearchActive }

    /// The peek detent. Fixed to the design's peek height rather than measured:
    /// the sheet compresses content that doesn't fit the detent, so feeding a
    /// measured (already-compressed) height back in sent it into a shrink loop.
    private var peekDetent: PresentationDetent { .height(SheetMetrics.peekHeight) }

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
                // Search - Focused (285:1589): the map dims and blurs behind
                // the expanded sheet.
                .overlay {
                    if isSearching {
                        Rectangle()
                            .fill(SheetPalette.searchScrim.opacity(0.6))
                            .background(.ultraThinMaterial)
                            .ignoresSafeArea()
                            .transition(.opacity)
                    }
                }
                // Ellipse 8 (285:1327): a big blurred blue blob sitting just
                // below the screen edge. The sheet's glass picks its colour up,
                // which is what gives the peek its blue cast.
                .overlay(alignment: .bottom) {
                    Ellipse()
                        .fill(SheetPalette.glow)
                        .frame(width: SheetMetrics.glowWidth, height: SheetMetrics.glowHeight)
                        .blur(radius: SheetMetrics.glowBlur)
                        .opacity(SheetMetrics.glowOpacity)
                        .offset(y: SheetMetrics.glowOffsetY)
                        .allowsHitTesting(false)
                        .ignoresSafeArea()
                }
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
                            .padding(.bottom, SheetMetrics.peekHeight + bottomSafeInset + 16)
                            .transition(.opacity)
                    }
                }
                .toolbar(path.isEmpty ? .hidden : .automatic, for: .navigationBar)
                .navigationDestination(for: HomeRoute.self) { route in
                    switch route {
                    case .place(let place):
                        // Place Details is a full page, not sheet content.
                        MockPlaceDetailView(place: place)
                            .navigationBarBackButtonHidden()
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
                        isExpanded: $isSearchActive,
                        searchText: $searchText,
                        searchRegion: visibleRegion,
                        onSelectPlace: openPlace,
                        onCancelSearch: dismissSearch
                    )
                    // While a place detail is showing, lock the sheet to the
                    // expanded detent — collapsing detail content to the 230pt
                    // peek cut it into an ugly sliver. Search/browse keeps both.
                    // Deliberately a constant set. Swapping the detents while
                    // the sheet is up makes it reconfigure mid-edit, which costs
                    // keystrokes; `isSearchActive` already keeps the content's
                    // appearance stable regardless of how iOS resizes the sheet
                    // around the keyboard.
                    .presentationDetents(
                        [peekDetent, expandedDetent],
                        selection: $sheetDetent
                    )
                    .presentationBackgroundInteraction(.enabled)
                    .presentationDragIndicator(.hidden)
                    // No presentationCornerRadius: iOS 26 already draws the
                    // design's 34pt top / 58pt bottom corners itself, pulling
                    // the bottom edges in at small heights. Pinning one radius
                    // overrode that.
                    // No explicit presentationBackground — the iOS 26 default
                    // sheet is Liquid Glass (translucent, map shows through).
                    // An explicit material override flattened it to gray.
                    .interactiveDismissDisabled()
                }
                .onChange(of: sheetDetent) { _, detent in
                    // Dragging the grabber up must behave exactly like tapping
                    // the field: the detent is a user gesture too, so mirror it
                    // into the search state rather than only reacting to focus.
                    let expanded = (detent == expandedDetent)
                    if expanded != isSearchActive {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isSearchActive = expanded
                        }
                    }
                }
                .onChange(of: isSearchActive) { _, active in
                    // The one place the search detent is set, so the sheet makes
                    // a single move rather than several racing writers.
                    sheetDetent = active ? expandedDetent : peekDetent
                }
                .onChange(of: path.count) { _, count in
                    if count == 0 {
                        // Back at the map root — bring the search sheet back
                        // at its peek height.
                        isSearchActive = false
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
            // The blue "current location" dot (with heading) — this is the
            // person's own position pin. The mock `Place.samples` pins that
            // used to sit alongside it are gone: main removed that fixture data
            // in favour of live results.
            UserAnnotation()
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
        GlassCircleButton {
            if let coordinate = locationManager.currentCoordinate {
                recenter(on: coordinate.clLocation, span: defaultMapSpan)
            } else {
                locationManager.requestLocation()
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("My location")
    }

    private func circularButton(systemName: String, action: @escaping () -> Void) -> some View {
        GlassCircleButton(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
        }
    }

    private func recenter(on coordinate: CLLocationCoordinate2D, span: Double = defaultMapSpan) {
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
        visibleRegion = region
    }

    /// ✕ / cancel: clear what was typed and collapse back to the peek. The
    /// sheet drops focus itself when `isSearchActive` goes false.
    private func dismissSearch() {
        searchText = ""
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearchActive = false
        }
    }

    private func openPlace(_ place: Place) {
        // Push the Place Details page. The sheet hides itself while the stack
        // is deeper than the root (see onChange(of: path.count)).
        isSearchActive = false
        path.append(HomeRoute.place(place))
    }

}

#Preview {
    HomeMapView()
}
