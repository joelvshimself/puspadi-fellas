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

let baliRegion = MKCoordinateRegion(
    center: CLLocationCoordinate2D(latitude: -8.7200, longitude: 115.2000),
    span: MKCoordinateSpan(latitudeDelta: 0.22, longitudeDelta: 0.22)
)

struct HomeMapView: View {
    @State private var cameraPosition: MapCameraPosition = .region(baliRegion)
    @State private var visibleRegion = baliRegion
    @State private var selectedMall: Place? = nil
    @State private var isSheetPresented = true
    @State private var sheetDetent: PresentationDetent = .height(SheetMetrics.peekHeight)
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
    @State private var nearbyPlaces: [Place] = []
    @State private var placeGrades: [UUID: OverallAccessibility] = [:]
    @State private var nearbyLoadTask: Task<Void, Never>?
    /// Top and bottom safe-area insets captured before map ignores safe area.
    @State private var topSafeInset: CGFloat = 54
    @State private var bottomSafeInset: CGFloat = 34

    private var isSearching: Bool { isSearchActive }

    /// The peek detent. Fixed to the design's peek height rather than measured:
    /// the sheet compresses content that doesn't fit the detent, so feeding a
    /// measured (already-compressed) height back in sent it into a shrink loop.
    private var peekDetent: PresentationDetent { .height(SheetMetrics.peekHeight) }

    var body: some View {
        GeometryReader { proxy in
            NavigationStack(path: $path) {
                mapLayer
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
                            .safeAreaPadding(.top)
                    }
                    .overlay(alignment: .topLeading) {
                        if showFilter {
                            // Options fan out to the right of the filter button,
                            // first row aligned with it (matches the mockup).
                            filterPanel
                                .padding(.leading, 72)
                                .safeAreaPadding(.top)
                                .transition(.opacity.combined(with: .move(edge: .leading)))
                        }
                    }
                    .overlay(alignment: .bottomTrailing) {
                        // Floated just above the peek sheet (which otherwise covers
                        // the screen bottom). Hidden while searching or filtering.
                        if !isSearching && !showFilter {
                            locationButton
                                .padding(.trailing, 16)
                                .padding(.bottom, SheetMetrics.peekHeight + 12)
                                .transition(.opacity)
                        }
                    }
                    .toolbar(path.isEmpty ? .hidden : .automatic, for: .navigationBar)
                    .navigationDestination(for: HomeRoute.self) { route in
                        switch route {
                        case .place(let place):
                            // Place Details is a full page, not sheet content.
                            MockPlaceDetailView(place: place)
                                .enableSwipeBack()
                        case .saved:
                            SavedView()
                                .enableSwipeBack()
                        case .contribute:
                            ContributeView()
                                .enableSwipeBack()
                        case .profile(let tab):
                            ProfileView(initialTab: tab)
                                .enableSwipeBack()
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
                        .presentationDetents(
                            [peekDetent, expandedDetent],
                            selection: $sheetDetent
                        )
                        .presentationBackgroundInteraction(.enabled(upThrough: expandedDetent))
                        .presentationContentInteraction(.scrolls)
                        .presentationCornerRadius(28)
                        .presentationDragIndicator(.hidden)
                        .interactiveDismissDisabled()
                    }
                    .onChange(of: sheetDetent) { _, detent in
                        let expanded = (detent == expandedDetent)
                        if expanded != isSearchActive {
                            withAnimation(.snappy(duration: 0.28)) {
                                isSearchActive = expanded
                            }
                        }
                    }
                    .onChange(of: isSearchActive) { _, active in
                        withAnimation(.snappy(duration: 0.28)) {
                            sheetDetent = active ? expandedDetent : peekDetent
                        }
                    }
                    .onChange(of: path.count) { _, count in
                        if count == 0 {
                            isSearchActive = false
                            sheetDetent = peekDetent
                            isSheetPresented = true
                        } else {
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
                        await loadNearbyPlaces()
                    }
                    .onDisappear {
                        nearbyLoadTask?.cancel()
                    }
            }
        }
    }

    private var displayedMalls: [Place] {
        let base = nearbyPlaces.map { place in
            var copy = place
            copy.grade = placeGrades[place.id] ?? place.grade
            return copy
        }
        if selectedGrades.isEmpty { return base }
        return base.filter { selectedGrades.contains($0.grade ?? .noData) }
    }

    @MainActor
    private func loadNearbyPlaces() async {
        let places = await NearbyPlacesService.search(in: visibleRegion)
        nearbyPlaces = places
        for place in places {
            if placeGrades[place.id] != nil { continue }
            if let response = try? await AccessibilityService.shared.enrich(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude,
                name: place.name
            ), let grades = response.grade, !grades.isEmpty {
                if grades.contains(where: { $0.bestValue == "no" }) {
                    placeGrades[place.id] = .notAccessible
                } else if grades.allSatisfy({ $0.bestValue == "yes" }) {
                    placeGrades[place.id] = .accessible
                } else {
                    placeGrades[place.id] = .partiallyAccessible
                }
            } else {
                placeGrades[place.id] = .noData
            }
        }
    }

    private var mapLayer: some View {
        Map(position: $cameraPosition, selection: $mapSelection) {
            UserAnnotation()

            ForEach(displayedMalls) { place in
                Annotation("", coordinate: place.coordinate, anchor: .bottom) {
                    CustomPinpointMarkerView(
                        name: place.name,
                        grade: place.grade ?? .noData,
                        isSelected: selectedMall?.id == place.id
                    )
                    .onTapGesture {
                        selectedMall = place
                        openPlace(place)
                    }
                }
            }
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
            scheduleNearbyPlacesLoad()
        }
        .onChange(of: mapSelection) { _, selection in
            handleMapSelection(selection)
        }
        .mapStyle(.standard(elevation: .realistic))
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

            // Profile button opens Profile Menu
            circularButton(systemName: "person.fill") {
                path.append(HomeRoute.profile())
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                    showAnalysing = true
                }
            )
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
                            .foregroundStyle(isOn ? grade.badgeForeground : .primary)
                            .frame(width: 44, height: 44)
                            .background {
                                Circle().fill(isOn ? grade.badgeBackground : Color(uiColor: .secondarySystemGroupedBackground))
                            }
                            .shadow(color: .black.opacity(0.18), radius: 6, y: 2)

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
        scheduleNearbyPlacesLoad()
    }

    private func scheduleNearbyPlacesLoad() {
        nearbyLoadTask?.cancel()
        nearbyLoadTask = Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            guard !Task.isCancelled else { return }
            await loadNearbyPlaces()
        }
    }

    /// ✕ / cancel: clear what was typed and collapse back to the peek. The
    /// sheet drops focus itself when `isSearchActive` goes false.
    private func dismissSearch() {
        searchText = ""
        withAnimation(.easeInOut(duration: 0.25)) {
            isSearchActive = false
        }
    }

    /// A tapped MapKit POI carries a name and coordinate — exactly what the
    /// accessibility lookup needs — so route it through the same openPlace()
    /// path a search result or a mall pin uses.
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

    private func openPlace(_ place: Place) {
        // Push the Place Details page. The sheet hides itself while the stack
        // is deeper than the root (see onChange(of: path.count)).
        isSearchActive = false
        path.append(HomeRoute.place(place))
    }
}

// MARK: - Custom Pinpoint Marker View

struct CustomPinpointMarkerView: View {
    let name: String
    var grade: OverallAccessibility = .accessible
    var isSelected: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .center) {
                // Teardrop colored pin body matching grade
                TeardropPinShape()
                    .fill(
                        LinearGradient(
                            colors: pinColors(for: grade),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(color: .black.opacity(0.35), radius: 5, x: 0, y: 3)

                // Accessibility symbol in center of pin head
                Image(systemName: grade.symbolName)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .offset(y: -9)
            }
            .frame(width: 32, height: 50)

            // Pin label tag
            Text(name)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                .shadow(color: .black.opacity(0.18), radius: 3, y: 2)
        }
    }

    private func pinColors(for grade: OverallAccessibility) -> [Color] {
        switch grade {
        case .accessible:
            [Color(red: 40 / 255, green: 180 / 255, blue: 70 / 255), Color(red: 25 / 255, green: 130 / 255, blue: 45 / 255)]
        case .partiallyAccessible:
            [Color(red: 255 / 255, green: 145 / 255, blue: 20 / 255), Color(red: 220 / 255, green: 90 / 255, blue: 0 / 255)]
        case .notAccessible:
            [Color(red: 235 / 255, green: 60 / 255, blue: 50 / 255), Color(red: 180 / 255, green: 30 / 255, blue: 20 / 255)]
        case .noData:
            [Color(red: 140 / 255, green: 140 / 255, blue: 145 / 255), Color(red: 100 / 255, green: 100 / 255, blue: 105 / 255)]
        }
    }
}

/// Teardrop pin geometry matching media_1787056690775.png
struct TeardropPinShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let radius = width / 2

        // Top circular head
        path.addArc(
            center: CGPoint(x: width / 2, y: radius),
            radius: radius,
            startAngle: .degrees(25),
            endAngle: .degrees(155),
            clockwise: true
        )
        // Stem tapering down to sharp point
        path.addLine(to: CGPoint(x: width / 2, y: height))
        path.closeSubpath()
        return path
    }
}

#Preview {
    HomeMapView()
        .environmentObject(LanguageManager.shared)
}
