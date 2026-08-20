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
    /// One grade at a time — the filter is a choice, not a combination.
    @State private var selectedGrade: OverallAccessibility?
    /// Set while the map is widening to look for a match, so the button can
    /// show it is working.
    @State private var isSearchingForGrade = false
    @State private var showFilter = false
    @State private var nearbyPlaces: [Place] = []
    /// Places the user has opened. The nearby sweep only queries for shopping
    /// malls, so anything else they tap — a hotel from Apple's own POI layer,
    /// say — would otherwise never get a pin, and so never show its grade.
    @State private var visitedPlaces: [Place] = []
    /// Grades keyed by rounded coordinate, NOT by `place.id`:
    /// `Place.fromSearchResult` mints a new UUID on every search, so an
    /// id-keyed cache never hit and each probe re-fetched every place.
    @State private var placeGrades: [String: OverallAccessibility] = [:]
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
                                // This overlay sits inside the safe area, so the
                                // button already clears the home indicator; adding
                                // the full peek height on top left a ~38pt gap.
                                // Tuned to sit ~12pt above the sheet's top edge.
                                .padding(.bottom, SheetMetrics.peekHeight - 14)
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
                        // No presentationCornerRadius: it takes ONE value for all
                        // four corners, and the design has 34pt top / 58pt bottom.
                        // That asymmetry is what iOS 26 already draws — the bottom
                        // edges pull in at small heights — so overriding it with a
                        // single 28 flattened the corners and lost both values.

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
                            Task { await refreshStaleGrades() }
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
        var seen = Set<String>()
        let combined = (nearbyPlaces + visitedPlaces).filter { seen.insert(Self.gradeKey(for: $0)).inserted }
        let base = combined.map { place in
            var copy = place
            copy.grade = placeGrades[Self.gradeKey(for: place)] ?? place.grade
            return copy
        }
        guard let selectedGrade else { return base }
        return base.filter { ($0.grade ?? .noData) == selectedGrade }
    }

    /// Searches a region and resolves grades WITHOUT touching `nearbyPlaces`
    /// or `visibleRegion`. The filter uses this to look ahead silently — moving
    /// the map at each step made the pins churn and the camera stutter.
    @MainActor
    private func probe(_ region: MKCoordinateRegion) async -> [Place] {
        let places = await NearbyPlacesService.search(in: region)
        // `.noData` means "the backend had no signal yet", not "this place has
        // no accessibility". Enrichment now finishes AFTER the first response,
        // so caching that answer permanently left map pins untagged while the
        // detail page — asking later — showed a real grade. Retry those.
        let missing = places.filter {
            let known = placeGrades[Self.gradeKey(for: $0)]
            return known == nil || known == .noData
        }

        // Bounded, and capped. This previously fired one enrich per un-graded
        // place with no limit — up to 25 at once, on every camera change. That
        // saturates a phone's connection (starving the map tiles competing for
        // it) and, since a cold enrich hits Google Places, spends real money
        // per pan. A few at a time, for the nearest handful, is plenty.
        if !missing.isEmpty {
            let batch = Array(missing.prefix(Self.maxGradesPerLoad))
            let pairs = await mapWithLimit(batch, limit: Self.maxConcurrentGradeLookups) { place in
                (Self.gradeKey(for: place), await Self.resolveGrade(for: place))
            }
            placeGrades.merge(Dictionary(uniqueKeysWithValues: pairs)) { _, new in new }
        }

        return places.map { place in
            var copy = place
            copy.grade = placeGrades[Self.gradeKey(for: place)] ?? place.grade
            return copy
        }
    }

    /// How many places get a grade lookup per load, and how many run at once.
    /// A pan should not cost 25 paid Google calls or 25 parallel connections.
    private static let maxGradesPerLoad = 8
    private static let maxConcurrentGradeLookups = 3

    /// Stable across searches, unlike `place.id`.
    private static func gradeKey(for place: Place) -> String {
        PlaceCacheStore.key(lat: place.coordinate.latitude, lng: place.coordinate.longitude)
    }

    private static func resolveGrade(for place: Place) async -> OverallAccessibility {
        guard let response = try? await AccessibilityService.shared.enrich(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            name: place.name
        ), let grades = response.grade, !grades.isEmpty else { return .noData }

        if grades.contains(where: { $0.bestValue == "no" }) { return .notAccessible }
        if grades.allSatisfy({ $0.bestValue == "yes" }) { return .accessible }
        return .partiallyAccessible
    }

    /// Fills in grades that are still unknown, without re-running the nearby
    /// search. Called on returning to the map, so a grade the detail page just
    /// resolved shows up on the pin instead of waiting for the next pan.
    @MainActor
    private func refreshStaleGrades() async {
        let stale = (nearbyPlaces + visitedPlaces).filter {
            let known = placeGrades[Self.gradeKey(for: $0)]
            return known == nil || known == .noData
        }
        guard !stale.isEmpty else { return }

        let batch = Array(stale.prefix(Self.maxGradesPerLoad))
        let pairs = await mapWithLimit(batch, limit: Self.maxConcurrentGradeLookups) { place in
            (Self.gradeKey(for: place), await Self.resolveGrade(for: place))
        }
        placeGrades.merge(Dictionary(uniqueKeysWithValues: pairs)) { _, new in new }
    }

    @MainActor
    private func loadNearbyPlaces() async {
        nearbyPlaces = await probe(visibleRegion)
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
            // The filter drives the camera itself and has already loaded the
            // places for its destination; re-querying here would fight it.
            guard !isSearchingForGrade else { return }
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
                if let selectedGrade {
                    Circle()
                        .fill(selectedGrade.badgeForeground)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.background, lineWidth: 2))
                        .offset(x: 4, y: -4)
                        .transition(.scale.combined(with: .opacity))
                }
            }

            Spacer()

            // Saved places and profile share one glass capsule, matching the
            // share/save pill on the place detail screen.
            HStack(spacing: 22) {
                Button {
                    path.append(HomeRoute.saved)
                } label: {
                    pillIcon("bookmark.fill")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Saved places")

                Button {
                    path.append(HomeRoute.profile())
                } label: {
                    pillIcon("person.fill")
                }
                .buttonStyle(.plain)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5).onEnded { _ in
                        showAnalysing = true
                    }
                )
                .accessibilityLabel("Profile")
                .accessibilityHint("Long press to open Analysing demo")
            }
            .padding(.horizontal, 16)
            .frame(height: SheetMetrics.buttonDiameter)
            .homeGlass(in: Capsule(), tint: .white.opacity(0.30))
            .shadow(
                color: .black.opacity(SheetMetrics.buttonShadowOpacity),
                radius: SheetMetrics.buttonShadowRadius,
                y: SheetMetrics.buttonShadowY
            )
        }
    }

    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // `.noData` is deliberately absent: it means "we have no signal",
            // which is not something anyone wants to filter *for*.
            ForEach(OverallAccessibility.allCases.filter { $0 != .noData }) { grade in
                let isOn = selectedGrade == grade
                Button {
                    selectGrade(grade)
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

    /// Picking a grade replaces any previous one, closes the panel, and then
    /// widens the map until at least one place with that grade is in view.
    /// Tapping the active grade again clears the filter.
    private func selectGrade(_ grade: OverallAccessibility) {
        let isClearing = (selectedGrade == grade)
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedGrade = isClearing ? nil : grade
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            showFilter = false
        }
        guard !isClearing else { return }
        nearbyLoadTask?.cancel()
        nearbyLoadTask = Task { await zoomOutUntilMatch(for: grade) }
    }

    /// Widens the region step by step, re-querying at each step, until a place
    /// with `grade` is in view. Gives up past `maxSpan` and leaves the map
    /// where it started rather than stranding the user zoomed out to nothing.
    @MainActor
    private func zoomOutUntilMatch(for grade: OverallAccessibility) async {
        let center = visibleRegion.center
        let startRegion = visibleRegion
        let maxSpan: Double = 2.0
        var span = max(visibleRegion.span.latitudeDelta, defaultMapSpan)

        isSearchingForGrade = true
        defer { isSearchingForGrade = false }

        while span <= maxSpan {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            )
            // Look ahead without moving the map: the camera should make one
            // deliberate move at the end, not a step per doubling.
            let found = await probe(region)
            guard !Task.isCancelled else { return }

            if found.contains(where: { ($0.grade ?? .noData) == grade }) {
                nearbyPlaces = found
                visibleRegion = region
                withAnimation(.easeInOut(duration: 0.65)) {
                    cameraPosition = .region(region)
                }
                // Let the animation finish before re-enabling camera-driven
                // reloads, or it queries mid-flight and stutters again.
                try? await Task.sleep(nanoseconds: 700_000_000)
                return
            }
            span *= 2
        }

        visibleRegion = startRegion
        withAnimation(.easeInOut(duration: 0.65)) {
            cameraPosition = .region(startRegion)
        }
        try? await Task.sleep(nanoseconds: 700_000_000)
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

    /// Icon inside the saved/profile capsule — the capsule owns the glass, so
    /// each icon only needs its own hit area.
    private func pillIcon(_ systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(.primary)
            .frame(width: 24, height: SheetMetrics.buttonDiameter)
            .contentShape(Rectangle())
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
        if !visitedPlaces.contains(where: { Self.gradeKey(for: $0) == Self.gradeKey(for: place) }) {
            visitedPlaces.append(place)
        }
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
