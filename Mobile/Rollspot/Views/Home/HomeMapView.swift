import MapKit
import UIKit
import Shared
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

private enum HomeFullScreenCover: String, Identifiable {
    case analysing
    case auth
    var id: String { rawValue }
}

struct HomeMapView: View {
    @EnvironmentObject private var auth: AuthSessionStore
    /// Shared-link arrivals (puspadifellas://place?…) land here as a pending
    /// place; this screen owns the navigation stack, so it does the routing.
    @ObservedObject private var deepLinks = DeepLinkRouter.shared
    @State private var homeCover: HomeFullScreenCover?
    /// Home "Continue Survey": the banner shows once per draft, then folds into the profile button.
    @ObservedObject private var drafts = ContributeDraftsStore.shared
    @State private var showContinueBanner = false
    @State private var foldedDraftId: String?
    @State private var resumePlace: Place?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Park23 search result always opens the contribute category menu.
    @State private var showPark23Contribute = false
    /// One-time intro sheet after signup. The flag persists so it is shown
    /// exactly once per device; the sheet stacks over the search sheet so it
    /// takes the same Liquid Glass treatment.
    @AppStorage("hasSeenOnboardingIntro") private var hasSeenOnboardingIntro = false
    @State private var showOnboardingIntro = false
    @State private var cameraPosition: MapCameraPosition = .region(baliRegion)
    @State private var visibleRegion = baliRegion
    /// Places, search and their debouncing live in the shared MapModel.
    @StateObject private var mapStore = MapStore()
    @State private var selectedMall: Place? = nil
    @State private var isSheetPresented = true
    @State private var sheetDetent: PresentationDetent = .height(SheetMetrics.peekHeight)
    @State private var isSearchActive = false
    @State private var searchText = ""
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
    private var selectedGrade: OverallAccessibility? { mapStore.gradeFilter }
    @State private var showFilter = false
    /// The first pin set depends on an Apple MapKit search, so make that empty
    /// interval explicit.
    @State private var isLoadingInitialPlaces = true
    /// Places the user has opened. The nearby sweep only queries for shopping
    /// malls, so anything else they tap — a hotel from Apple's own POI layer,
    /// say — would otherwise never get a pin, and so never show its grade.
    /// Top and bottom safe-area insets captured before map ignores safe area.
    @State private var topSafeInset: CGFloat = 54
    @State private var bottomSafeInset: CGFloat = 34

    private var isSearching: Bool { isSearchActive }
    private var nearbyPlaces: [Place] { mapStore.places }

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
                    .overlay {
                        if isLoadingInitialPlaces && path.isEmpty {
                            initialPlacesLoadingOverlay
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
                        VStack(spacing: 12) {
                            topBar
                            if showContinueBanner, let waiting = drafts.waiting, !isSearching, !showFilter {
                                ContinueSurveyBanner(contribution: waiting) { resume(waiting) }
                                    .homeGlass(in: RoundedRectangle(cornerRadius: 20, style: .continuous), tint: .white.opacity(0.55))
                                    .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
                                    // Folds up into the profile button, which then carries the badge.
                                    .transition(.asymmetric(
                                        insertion: .move(edge: .top).combined(with: .opacity),
                                        removal: reduceMotion ? .opacity : .scale(scale: 0.15, anchor: .topTrailing).combined(with: .opacity)
                                    ))
                            }
                        }
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
                            // `.id` ties the view's identity to the place:
                            // replacing the top of the stack in one transaction
                            // (a share link opened while another place is up)
                            // otherwise reuses the view and its @StateObject
                            // store keeps showing the PREVIOUS place's data.
                            MockPlaceDetailView(place: place)
                                .id(place.id)
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
                    .sheet(isPresented: $isSheetPresented) {
                        SearchSheet(
                            isExpanded: $isSearchActive,
                            searchText: $searchText,
                            store: mapStore,
                            nearbyPlaces: gradedPlaces,
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
                        // The one-time intro stacks over the search sheet the
                        // same way the auth cover does, so the search sheet
                        // never has to dismiss/re-present around it. A custom
                        // fraction (not .large) keeps the Liquid Glass look.
                        .sheet(isPresented: $showOnboardingIntro) {
                            OnboardingIntroSheet(onExplore: {
                                hasSeenOnboardingIntro = true
                                showOnboardingIntro = false
                            })
                            .presentationDetents([.fraction(0.81)])
                            .presentationDragIndicator(.hidden)
                            .interactiveDismissDisabled()
                        }
                        // The cover is presented FROM the sheet, not from the map
                        // underneath it. Presenting it below the sheet forced a
                        // dismiss/re-present cycle around every login, and a sheet
                        // re-presented while the cover was still animating away
                        // came back as a default .large sheet — custom detents
                        // ignored, the peek pill floating mid-screen. From up
                        // here the sheet never moves: the cover slides over it
                        // and dismissing the cover simply reveals it again.
                        .fullScreenCover(item: $resumePlace) { place in
                            ContributeReviewFlowView(
                                place: place,
                                initialScreenIndex: UnfinishedReviewStore.snapshot(for: place)?.screenIndex ?? 0
                            ) {
                                resumePlace = nil
                            }
                            .environmentObject(auth)
                        }
                        .fullScreenCover(isPresented: $showPark23Contribute) {
                            ContributeReviewFlowView(
                                place: .park23Demo,
                                initialScreenIndex: 0,
                                ignoreDraftRestore: true
                            ) {
                                showPark23Contribute = false
                            }
                            .environmentObject(auth)
                        }
                        .fullScreenCover(item: $homeCover) { cover in
                            switch cover {
                            case .analysing:
                                AnalysingView(onDismiss: { homeCover = nil })
                            case .auth:
                                LoginView(
                                    onSuccess: {
                                        dismissAuthToHome(showIntroIfNeeded: true)
                                    },
                                    onCancel: {
                                        homeCover = nil
                                    },
                                    onExploreMalls: {
                                        dismissAuthToHome(showIntroIfNeeded: false)
                                    }
                                )
                                .environmentObject(auth)
                            }
                        }
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
                            mapStore.refresh()
                        } else {
                            isSheetPresented = false
                        }
                    }
                    .onChange(of: locationManager.currentCoordinate) { _, coordinate in
                        guard let coordinate, !hasCenteredOnUser else { return }
                        hasCenteredOnUser = true
                        recenter(on: coordinate.clLocation)
                    }
                    .onChange(of: mapStore.focusNonce) { _, _ in
                        guard let region = mapStore.focusRegion else { return }
                        visibleRegion = region
                        withAnimation(.easeInOut(duration: 0.65)) {
                            cameraPosition = .region(region)
                        }
                    }
                    .onChange(of: mapStore.hasLoadedOnce) { _, loaded in
                        guard loaded else { return }
                        withAnimation(.easeOut(duration: 0.2)) {
                            isLoadingInitialPlaces = false
                        }
                    }
                    .onChange(of: deepLinks.pendingPlace) { _, place in
                        openDeepLinkedPlace(place)
                    }
                    .onChange(of: drafts.waiting?.placeId, initial: true) { _, placeId in
                        presentContinueBanner(for: placeId)
                    }
                    .task {
                        // A link that launched the app may have landed before
                        // this view existed — drain it here as well.
                        openDeepLinkedPlace(deepLinks.pendingPlace)
                        locationManager.requestLocation()
                        // Through the debounce, not a direct load: the map's
                        // first render also fires onMapCameraChange, so a
                        // direct call here ran two identical nearby searches
                        // side by side on every launch.
                        scheduleNearbyPlacesLoad()
                        #if DEBUG
                        if await applyDesignReview() { return }
                        #endif
                        if !hasSeenOnboardingIntro {
                            try? await Task.sleep(nanoseconds: 700_000_000)
                            showOnboardingIntro = true
                        }
                        #if DEBUG
                        // `xcrun simctl launch <sim> com.puspadifellas.app -previewOnboarding`
                        // forces the one-time intro sheet for design review.
                        if ProcessInfo.processInfo.arguments.contains("-previewOnboarding") {
                            try? await Task.sleep(nanoseconds: 800_000_000)
                            showOnboardingIntro = true
                        }
                        #endif
                    }
            }
        }
    }

    /// Every place for the visible region, before the grade filter. The search
    /// sheet lists these so it never re-queries what the map already loaded.
    private var gradedPlaces: [Place] { nearbyPlaces }

    /// What the map draws, decided by the shared MapModel (same as Android).
    private var displayedMalls: [Place] { mapStore.visiblePlaces }

    private var mapLayer: some View {
        Map(position: $cameraPosition, selection: $mapSelection) {
            UserAnnotation()

            ForEach(displayedMalls) { place in
                Annotation("", coordinate: place.coordinate, anchor: .center) {
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
        // Place data is from OpenStreetMap (ODbL): the credit must be visible on the map.
        .overlay(alignment: .bottomLeading) {
            Text(verbatim: PlaceRepository.companion.ATTRIBUTION)
                .font(.system(size: 9))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 3))
                .padding(.leading, 8)
                // Above the collapsed search sheet, which covers the bottom ~100pt.
                .padding(.bottom, 112)
                .allowsHitTesting(false)
        }
        .onMapCameraChange { context in
            visibleRegion = context.region
            // The model ignores camera changes while the filter is widening.
            scheduleNearbyPlacesLoad()
        }
        .onChange(of: mapSelection) { _, selection in
            handleMapSelection(selection)
        }
        .mapStyle(.standard(elevation: .realistic))
    }

    /// A subdued map-loading treatment for the first request. It makes the map
    /// look intentionally unavailable rather than like it has no places, while
    /// the app chrome and search sheet remain above it.
    private var initialPlacesLoadingOverlay: some View {
        ZStack {
            Rectangle()
                .fill(.black.opacity(0.14))
                .background(.thinMaterial)

            VStack(spacing: 10) {
                ProgressView()
                    .controlSize(.regular)
                Text("Loading nearby places")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.primary)
        }
        .ignoresSafeArea()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Loading nearby places")
        .accessibilityAddTraits(.updatesFrequently)
        .allowsHitTesting(false)
    }

    private var topBar: some View {
        HStack {
            circularButton(systemName: "line.3.horizontal.decrease") {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showFilter.toggle()
                }
            }
            .overlay(alignment: .topTrailing) {
                if selectedGrade != nil {
                    // Design "FILTER CHOSEN": a blue badge counting the active filter.
                    Text("1")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(AuthPalette.brandBlue))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .offset(x: 4, y: -4)
                        .transition(.scale(scale: 0.6).combined(with: .opacity))
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
                // Without `.plain` the label inherits the accent tint and both
                // icons render blue instead of the design's black.
                .buttonStyle(.plain)
                .accessibilityLabel("Saved places")

                Button {
                    openProfile()
                } label: {
                    pillIcon("person.fill")
                        .overlay(alignment: .topTrailing) {
                            if drafts.waiting != nil && !showContinueBanner {
                                // The folded "Continue Survey" banner: one contribution waiting.
                                Text("1")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 18, height: 18)
                                    .background(Circle().fill(AuthPalette.brandBlue))
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .offset(x: 12, y: 2)
                                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Profile")
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
                            // Design: solid grade-colored disc with a ✓ / ! / ✕ glyph.
                            Image(systemName: grade.filterGlyph)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background { Circle().fill(grade.pinColor) }
                                .overlay { Circle().strokeBorder(.white, lineWidth: isOn ? 3 : 0) }
                                .shadow(color: .black.opacity(0.18), radius: 6, y: 2)
                            
                            Text(grade.filterLabel)
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
        
        /// Picking a grade replaces any previous one and closes the panel; tapping the
        /// active grade again clears it. The shared model widens the search area
        /// until a match is found, then `focusRegion` moves the camera there.
        private func selectGrade(_ grade: OverallAccessibility) {
            withAnimation(.easeInOut(duration: 0.2)) {
                mapStore.setGradeFilter(grade)
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showFilter = false
            }
        }
        
        private var isLocationDenied: Bool {
            locationManager.authorizationStatus == .denied
            || locationManager.authorizationStatus == .restricted
        }
        
        private var locationButton: some View {
            GlassCircleButton {
                // Denied was silently doing nothing: requestLocation() falls
                // through to `default: break`, so the button was dead with no
                // feedback at all. Send the user somewhere they can fix it.
                if isLocationDenied {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } else if let coordinate = locationManager.currentCoordinate {
                    recenter(on: coordinate.clLocation, span: defaultMapSpan)
                } else {
                    locationManager.requestLocation()
                }
            } label: {
                Image(systemName: isLocationDenied ? "location.slash.fill" : "location.fill")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isLocationDenied ? Color.secondary : Color.primary)
            }
            .accessibilityLabel(isLocationDenied ? "Location access off — open Settings" : "My location")
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
        
        /// The shared model debounces, so this is cheap to call on every settled camera change.
        private func scheduleNearbyPlacesLoad() {
            mapStore.regionChanged(visibleRegion)
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

    /// Routes a shared-link place onto the navigation stack, popping whatever
    /// was open first so the link always lands on its own detail page.
    private func openDeepLinkedPlace(_ place: Place?) {
        guard let place else { return }
        deepLinks.pendingPlace = nil
        homeCover = nil
        if !path.isEmpty {
            path = NavigationPath()
        }
        openPlace(place)
    }

    /// Shows the banner for a draft the user hasn't seen yet this launch, then folds it away.
    private func presentContinueBanner(for placeId: String?) {
        guard let placeId, placeId != foldedDraftId else {
            if placeId == nil { showContinueBanner = false }
            return
        }
        withAnimation(.easeOut(duration: 0.25)) { showContinueBanner = true }
        Task {
            try? await Task.sleep(for: .seconds(4))
            guard drafts.waiting?.placeId == placeId else { return }
            withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.45, dampingFraction: 0.85)) {
                showContinueBanner = false
                foldedDraftId = placeId
            }
        }
    }

    private func resume(_ contribution: WaitingContribution) {
        withAnimation(.easeOut(duration: 0.2)) {
            showContinueBanner = false
            foldedDraftId = contribution.placeId
        }
        resumePlace = drafts.place(for: contribution)
    }

    private func openProfile(tab: ProfileTab = .reviews) {
        if auth.isSignedIn {
            path.append(HomeRoute.profile(tab))
        } else {
            // The sheet STAYS presented: the auth cover is attached to the
            // sheet's content and slides over everything. Dismissing the sheet
            // first (an earlier fix that merged in from another branch) tore
            // down the very view the cover presents from — "not in the window
            // hierarchy" — so the login never appeared.
            isSearchActive = false
            homeCover = .auth
        }
    }

    /// Closes the auth cover and returns to the map root. Sign-in never
    /// auto-opens Profile — even when login was triggered from the profile
    /// button — so every completed auth lands on the home map.
    private func dismissAuthToHome(showIntroIfNeeded: Bool) {
        homeCover = nil
        if !path.isEmpty {
            path = NavigationPath()
        }
        isSearchActive = false
        guard showIntroIfNeeded, !hasSeenOnboardingIntro else { return }
        // Wait out the cover's dismiss animation — presenting while it is
        // still animating drops the sheet.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
            showOnboardingIntro = true
        }
    }

    #if DEBUG
    /// Puts Home into the state a `-designReview home*` launch asks for. Returns true for home
    /// review screens so the one-time intro sheet stays out of the screenshot.
    private func applyDesignReview() async -> Bool {
        guard let screen = DesignReview.current, screen.rawValue.hasPrefix("home") else { return false }
        try? await Task.sleep(nanoseconds: 1_500_000_000) // let nearby places load first
        switch screen {
        case .homeFilter: showFilter = true
        case .homeFilterChosen: mapStore.setGradeFilter(.accessible)
        case .homeSearch: isSearchActive = true
        case .homeSearchQuery:
            isSearchActive = true
            searchText = "beach"
        default: break
        }
        return true
    }
    #endif

    private func openPlace(_ place: Place) {
        if place.isPark23Demo {
            isSearchActive = false
            showPark23Contribute = true
            return
        }
        isSearchActive = false
        mapStore.opened(place)
        searchText = ""
        path.append(HomeRoute.place(place))
    }
}
        
        // MARK: - Custom Pinpoint Marker View
        
        struct CustomPinpointMarkerView: View {
            let name: String
            var grade: OverallAccessibility = .accessible
            var isSelected: Bool = false
            
            /// The Figma pin: a grade-colored disc with a white ring and a ✓ / ! / ✕ glyph.
            var body: some View {
                ZStack {
                    Circle()
                        .fill(grade.pinColor)
                        .frame(width: 28, height: 28)
                        .overlay { Circle().strokeBorder(.white, lineWidth: 2.5) }
                        .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
                    if let glyph = grade.pinGlyph {
                        Image(systemName: glyph)
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(.white)
                    }
                }
                .scaleEffect(isSelected ? 1.25 : 1)
                .animation(.snappy(duration: 0.2), value: isSelected)
                .accessibilityLabel(name)
                .accessibilityValue(grade.label)
            }
        }
        
        extension OverallAccessibility {
            /// Same colors as Android's pins and badges.
            var pinColor: Color {
                switch self {
                case .accessible: Color(red: 40 / 255, green: 180 / 255, blue: 69 / 255)
                case .partiallyAccessible: Color(red: 255 / 255, green: 145 / 255, blue: 20 / 255)
                case .notAccessible: Color(red: 235 / 255, green: 60 / 255, blue: 50 / 255)
                case .noData: .gray
                }
            }
            
            var pinGlyph: String? {
                switch self {
                case .accessible: "checkmark"
                case .partiallyAccessible: "exclamationmark"
                case .notAccessible: "xmark"
                case .noData: nil
                }
            }
            
            var filterGlyph: String { pinGlyph ?? "questionmark" }
            
            /// The filter says "Partially Accessible" (Figma); badges elsewhere keep "Moderately".
            var filterLabel: String {
                self == .partiallyAccessible ? "Partially Accessible".localized : label
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
                .environmentObject(AuthSessionStore())
        }
