import CoreLocation
import SwiftUI

/// Primary place details screen — hero carousel, grade banner, and the
/// Overview / Reviews / Photos sections scoped to one facility at a time
/// (Figma "Place Details").
struct MockPlaceDetailView: View {
    let place: Place

    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store: PlaceReviewStore

    /// Observed rather than copied into local state: the saved set also
    /// changes from sign-in and from the Saved list, and a snapshot taken in
    /// `onAppear` went stale on both.
    @ObservedObject private var savedPlaces = SavedPlacesService.shared
    @State private var saveToast: String?
    @State private var saveError: String?
    @State private var showSignIn = false
    /// What the user was doing when the sign-in gate interrupted, resumed
    /// after a successful login. EVERY authenticated action gates up front —
    /// Save already did, but Contribute/review entry points used to open
    /// their flow first and pop a login a beat later, which read as two
    /// competing prompts.
    private enum AuthGatedAction { case save, review }
    @State private var pendingAuthAction: AuthGatedAction?
    @State private var heroPage: Int? = 0
    @State private var showReviewWizard = false
    @State private var resumeScreenIndex = 0
    /// First-visit "Share what you know" spotlight (Figma "Intro to
    /// contribute") — shown once per install, ever.
    @AppStorage("hasSeenContributeIntro") private var hasSeenContributeIntro = false
    @State private var showContributeIntro = false
    /// "Your review submitted!" row at the top of Reviews after the wizard
    /// posts (Figma "Reviewed" state, with its bigger-then-settle reveal).
    @State private var showSubmittedBanner = false
    @State private var reviewJustSubmitted = false
    @State private var showMyReview = false

    @State private var selectedSection: PlaceDetailSection = .overview
    @State private var selectedFacility: FacilityKind = .entrance
    @State private var contentWidth: CGFloat = 0
    @State private var photoSource: PhotoComposerSource?
    @State private var lightbox: LightboxSelection?

    private let heroHeight: CGFloat = 253

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    init(place: Place) {
        self.place = place
        _store = StateObject(wrappedValue: PlaceReviewStore(place: place))
    }

    private var heroURLs: [URL] {
        store.reviewPhotos.compactMap(\.imageURL)
    }

    /// Downloads the carousel's images ahead of the swipe, a couple at a time
    /// so it does not compete with the first slide the user is actually
    /// looking at.
    private func prefetchCarousel() async {
        guard !heroURLs.isEmpty else { return }
        _ = await mapWithLimit(heroURLs, limit: 2) { url in
            _ = try? await NetworkRetry.download(from: url)
        }
    }

    private var totalHeroCount: Int {
        max(1, (store.streetImageURL != nil ? 1 : 0) + heroURLs.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    // Overlaps the photo by its corner radius so the rounded
                    // top corners are visible against the hero.
                    gradeBanner
                        .padding(.top, -18)
                        .zIndex(1)
                    contentSection
                        .background(Color(.systemBackground))
                }
            }
            .coordinateSpace(name: "heroScroll")

            topControls
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        // Dim UNDER the pill overlay below, so the pill stays bright —
        // that's the spotlight.
        .overlay {
            if showContributeIntro {
                ContributeIntroOverlay { dismissContributeIntro() }
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            // The empty state carries its own filled Contribute button; a
            // floating pill on top of it would be the same CTA twice. And no
            // pill over the loading skeleton — it may resolve into that state.
            if !isEmptyState && !isInitialLoading {
                ZStack(alignment: .bottom) {
                    ContributeGlow()
                    ContributeFloatingButton {
                        dismissContributeIntro()
                        startReview()
                    }
                    .padding(.bottom, 20)
                }
            }
        }
        .task {
            await store.load()
            store.startWatching()
            if !hasSeenContributeIntro && !isEmptyState {
                try? await Task.sleep(for: .milliseconds(600))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.3)) { showContributeIntro = true }
            }
        }
        // Warm the rest of the carousel while the first slide is being looked
        // at. AsyncImage only fetches a page when it comes into view, so every
        // swipe used to start its own download; downloading them up front
        // through the same URLSession puts them in URLCache, and the swipe
        // then resolves from cache instead of from the network.
        .task(id: heroURLs) {
            await prefetchCarousel()
        }
        // Hidden, not just transparent: the bar stayed in the hierarchy at
        // ~0-103pt and hit-tested first, so every tap on the share/save pill
        // (which the design puts at 60pt) went to the bar instead of to the
        // buttons. The screen draws its own back control below.
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            if let saveToast {
                PhotoSuccessToast(message: saveToast) { self.saveToast = nil }
                    .padding(.horizontal, 20)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.25), value: saveToast)
        .alert(
            "Couldn't update your saved places",
            isPresented: Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } }),
            presenting: saveError
        ) { _ in
            Button("OK") { saveError = nil }
        } message: { message in
            Text(message)
        }
        .fullScreenCover(isPresented: $showSignIn) {
            LoginView(
                onSuccess: {
                    showSignIn = false
                    // Finish what the tap was for, now that there is a user.
                    switch pendingAuthAction {
                    case .save: Task { await toggleSave() }
                    case .review: openReviewWizard()
                    case nil: break
                    }
                    pendingAuthAction = nil
                },
                onCancel: {
                    showSignIn = false
                    pendingAuthAction = nil
                },
                onExploreMalls: { showSignIn = false }
            )
            .environmentObject(auth)
        }
        .fullScreenCover(isPresented: $showReviewWizard) {
            ContributeReviewFlowView(
                place: place,
                startingFacility: selectedFacility,
                initialScreenIndex: resumeScreenIndex,
                onSubmitted: { reviewJustSubmitted = true }
            ) {
                showReviewWizard = false
                UnfinishedReviewStore.clear(for: place)
                if reviewJustSubmitted {
                    reviewJustSubmitted = false
                    // Land on Reviews with the "submitted!" row revealing a
                    // little bigger first, then settling (design dev note).
                    selectedSection = .reviews
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.65)) {
                        showSubmittedBanner = true
                    }
                }
                Task {
                    // Drop the cached grade first or load() republishes the
                    // pre-review grade and the banner only updates if the
                    // realtime insert happens to arrive.
                    await PlaceCacheStore.shared.remove(store.placeId)
                    await store.load()
                }
            }
        }
        // Add Photos goes straight to the source menu and then the composer
        // (Figma "Photos - Adding Photo" → "Photos - Confirm photos"). It used
        // to open a second gallery screen with its own dead Overview/Reviews
        // tabs and a second Add Photos button before the picker ever appeared.
        .photoComposerFlow(
            source: $photoSource,
            place: place,
            facility: selectedFacility,
            onUploaded: { _ in
                showToast("Your photos successfully added!".localized)
                Task { await store.load() }
            }
        )
        .fullScreenCover(item: $lightbox) { selection in
            FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
        }
        .fullScreenCover(isPresented: $showMyReview) {
            MockMyReviewView()
        }
    }

    private var heroSection: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("heroScroll")).minY
            let stretch = max(0, minY)
            let height = heroHeight + stretch

            ZStack(alignment: .top) {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(0..<totalHeroCount, id: \.self) { index in
                            heroSlide(index: index, width: geo.size.width, height: height)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $heroPage)
                .scrollTargetBehavior(.paging)
                .frame(width: geo.size.width, height: height)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 90)
                    .allowsHitTesting(false)
                }

                VStack {
                    Spacer()
                    bottomOverlay
                }
                .frame(height: height)
            }
            .offset(y: -stretch)
        }
        .frame(height: heroHeight)
    }

    @ViewBuilder
    private func heroSlide(index: Int, width: CGFloat, height: CGFloat) -> some View {
        if index == 0, let street = store.streetImageURL {
            AsyncImage(url: street) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    PlaceImageView(
                        coordinate: place.coordinate,
                        remoteImageURL: street,
                        attribution: store.imageAttribution,
                        resolved: store.enrichResolved,
                        height: height,
                        cornerRadius: 0
                    )
                }
            }
            .frame(width: width, height: height)
            .clipped()
        } else {
            let photoIndex = store.streetImageURL != nil ? index - 1 : index
            if photoIndex >= 0, photoIndex < heroURLs.count {
                AsyncImage(url: heroURLs[photoIndex]) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Color(.secondarySystemBackground)
                    }
                }
                .frame(width: width, height: height)
                .clipped()
            } else {
                PlaceImageView(
                    coordinate: place.coordinate,
                    remoteImageURL: nil,
                    attribution: store.imageAttribution,
                    resolved: store.enrichResolved,
                    height: height,
                    cornerRadius: 0
                )
                .frame(width: width, height: height)
                .clipped()
            }
        }
    }

    private var saveId: String {
        Place.canonicalPlaceId(from: place.coordinate)
    }

    private var isSaved: Bool {
        savedPlaces.isSaved(placeId: saveId)
    }

    private func toggleSave() async {
        switch await savedPlaces.toggleSave(placeId: saveId, place: place) {
        case .saved:
            showToast("Saved to your places".localized)
        case .removed:
            showToast("Removed from your saved places".localized)
        case .needsSignIn:
            pendingAuthAction = .save
            showSignIn = true
        case .failed(let message):
            saveError = message
        }
    }

    private func showToast(_ message: String) {
        saveToast = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            if saveToast == message { saveToast = nil }
        }
    }

    private var topControls: some View {
        HStack {
            GlassCircleButton(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.black)
            }
            .accessibilityLabel("Back")

            Spacer()

            HStack(spacing: 22) {
                Button { sharePlace() } label: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    Task { await toggleSave() }
                } label: {
                    Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background {
                Capsule().fill(Color.white.opacity(0.55))
                Capsule().fill(.ultraThinMaterial)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private var bottomOverlay: some View {
        let activePage = heroPage ?? 0
        return HStack {
            if totalHeroCount > 1 {
                HStack(spacing: 4) {
                    ForEach(0..<totalHeroCount, id: \.self) { index in
                        if index == activePage {
                            Capsule().fill(.white).frame(width: 27, height: 4)
                        } else {
                            Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
                        }
                    }
                }
                .animation(.snappy(duration: 0.2), value: activePage)
            }

            Spacer()

            NavigationLink {
                MockGalleryView(
                    streetImageURL: store.streetImageURL,
                    reviewPhotos: store.reviewPhotos,
                    place: place,
                    onPhotosChanged: { Task { await store.load() } }
                )
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("GALLERY".localized)
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background {
                    Capsule().fill(Color.white.opacity(0.55))
                    Capsule().fill(.ultraThinMaterial)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        // 14pt of clearance above the grade banner, which now covers the
        // bottom 18pt of the hero.
        .padding(.bottom, 32)
    }

    /// Full-bleed grade strip between the hero and the title — the badge that
    /// used to sit inside the info card.
    @ViewBuilder
    private var gradeBanner: some View {
        // Resolution has to be checked FIRST. `overallGrade` falls back to
        // `.noData` when there are no feature grades yet, so it is never nil —
        // which made the placeholder below unreachable and showed a confident
        // "NO DATA AVAILABLE" that then flipped to the real grade.
        if !store.enrichResolved {
            AccessibilityBannerPlaceholder()
        } else if let grade = store.overallGrade {
            AccessibilityBanner(grade: grade)
        }
    }

    /// Still fetching, with nothing meaningful to lay out yet. Distinct from
    /// the empty state on purpose: "loading" gets a skeleton; "empty" is a
    /// settled fact. A cached grade alone is NOT enough — the tabs need the
    /// reviews, so the skeleton holds until that fetch has completed once.
    private var isInitialLoading: Bool {
        store.isLoading || !store.reviewsAttempted
    }

    /// No community contributions yet — no reviews and no photos. The design
    /// collapses the whole tab apparatus into one "Know something about the
    /// place?" ask (frame "Empty") instead of three tabs of empty cards; the
    /// banner above still shows whatever grade enrichment derived.
    private var isEmptyState: Bool {
        !isInitialLoading
            && store.enrichResolved
            && store.reviewsResolved
            && !store.hasAnyReviews()
            && store.reviewPhotos.isEmpty
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            titleBlock
                .padding(.horizontal, 22)
                .padding(.top, 18)

            if isInitialLoading {
                PlaceDetailLoadingSkeleton()
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                    .padding(.bottom, 96)
            } else if isEmptyState {
                emptyStateContent
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                    .padding(.bottom, 40)
            } else {
                PlaceDetailTabBar(
                    selection: $selectedSection,
                    reviewCount: allReviews.count
                )
                .padding(.top, 18)

                // Reviews replaces the facility chips with its own filter
                // chips (ALL / WITH PHOTOS / tags) — see FacilityReviewsList.
                if selectedSection != .reviews {
                    FacilityChipRow(selection: $selectedFacility)
                        .padding(.top, 18)
                }

                sectionContent
                    .padding(.top, 22)
                    // Clears the floating CONTRIBUTE pill.
                    .padding(.bottom, 96)
            }
        }
        .background {
            GeometryReader { geo in
                Color.clear.preference(key: DetailWidthKey.self, value: geo.size.width)
            }
        }
        .onPreferenceChange(DetailWidthKey.self) { contentWidth = $0 }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(place.name)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                PlaceActionPill(icon: "location.fill", title: "Open in Maps", action: openMaps)
                PlaceActionPill(icon: "phone.fill", title: "Call", action: callWhatsApp)
                Spacer(minLength: 0)
            }
        }
    }

    private var emptyStateContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hairline between the action pills and the ask, per the design.
            Divider()
                .padding(.bottom, 4)

            Text("Know something about the place?".localized)
                .font(.system(size: 17, weight: .semibold))

            Button { startReview() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text("Contribute Information".localized)
                        .font(.system(size: 17, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var facilityReviews: [PlaceFacilityReview] {
        store.reviews(for: selectedFacility)
    }

    /// The Reviews tab lists every facility's reviews together (the design's
    /// count is the place total, not the selected facility's).
    private var allReviews: [PlaceFacilityReview] {
        store.facilityReviews.sorted { $0.createdAt > $1.createdAt }
    }

    /// Every tag the community confirmed for this facility, newest review
    /// first — not just the latest review's, so one thin review does not hide
    /// what earlier reviewers reported.
    private var providedTags: [String] {
        var seen = Set<String>()
        return facilityReviews
            .flatMap(\.providedTags)
            .filter { $0 != "NOT AVAILABLE" && seen.insert($0).inserted }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewContent
                .padding(.horizontal, 22)
        case .reviews:
            reviewsContent
                .padding(.horizontal, 22)
        case .photos:
            photosContent
                .padding(.horizontal, 22)
        }
    }

    private var overviewContent: some View {
        let notes = store.noteSnippets(for: selectedFacility)
        return VStack(alignment: .leading, spacing: 24) {
            WhatProvidedCard(
                tags: providedTags,
                isUnavailable: store.isUnavailable(selectedFacility),
                facilityName: selectedFacility.title
            )

            NotesFromReviewsSection(
                snippets: notes,
                onOpenReviews: { withAnimation(.snappy(duration: 0.22)) { selectedSection = .reviews } }
            )

            // The empty notes card already carries a "Be the first reviewer"
            // button — a second identical CTA right under it is noise, so this
            // block only appears once there is something to disagree with.
            if !notes.isEmpty {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Find something different?".localized)
                        .font(.system(size: 20, weight: .bold))

                    // Quiet capsule, blue label — the design reserves the
                    // filled blue button for first contributions; editing
                    // existing info is the secondary treatment.
                    Button { startReview() } label: {
                        Text(reviewCTATitle.localized)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(PhotoPalette.brandBlue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.mockSectionBackground, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var reviewCTATitle: String {
        if UnfinishedReviewStore.hasUnfinished(for: place) { return "Unfinished review" }
        return store.hasAnyReviews() ? "Edit Accessibility Information" : "Be the first reviewer"
    }

    /// "🗨 Your review submitted!" — tappable row above the reviews list,
    /// opening the My Review screen (Figma "Reviewed" → "My Review").
    private var submittedBanner: some View {
        Button { showMyReview = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(PhotoPalette.brandBlue)
                Text("Your review submitted!".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(PhotoPalette.brandBlue.opacity(0.10))
            )
        }
        .buttonStyle(.plain)
        .transition(.scale(scale: 1.1).combined(with: .opacity))
    }

    private func dismissContributeIntro() {
        hasSeenContributeIntro = true
        guard showContributeIntro else { return }
        withAnimation(.easeIn(duration: 0.2)) { showContributeIntro = false }
    }

    // One explicit container, NOT a bare @ViewBuilder tuple: SwiftUI
    // distributes modifiers over tuples, so the section's top/bottom padding
    // was being applied to the banner AND the list separately — ~130pt of
    // phantom space opened up between them.
    private var reviewsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showSubmittedBanner {
                submittedBanner
                    .padding(.bottom, 16)
            }
            reviewsList
        }
    }

    @ViewBuilder
    private var reviewsList: some View {
        if allReviews.isEmpty {
            // The design's "No Review Yet" frame is exactly this: quiet text,
            // no card, no button — the floating CONTRIBUTE pill is the CTA.
            Text("No Review Yet".localized)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            FacilityReviewsList(reviews: allReviews)
        }
    }

    private var photosContent: some View {
        let photos = store.facilityPhotos(for: selectedFacility)
        return VStack(spacing: 16) {
            // The design's "Click add photo" state is a small MENU next to the
            // button (Choose Existing / Take New Photo), not an action sheet.
            Menu {
                Button { photoSource = .library } label: {
                    Label("Choose Existing".localized, systemImage: "photo.on.rectangle")
                }
                Button { photoSource = .camera } label: {
                    Label("Take New Photo".localized, systemImage: "camera")
                }
                .disabled(!CameraPicker.isAvailable)
            } label: {
                HStack(spacing: PhotoMetrics.addPhotosSpacing) {
                    Image(systemName: "photo.badge.plus.fill")
                        .font(.system(size: 20))
                    Text("Add Photos".localized)
                        .font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .semibold))
                }
                .foregroundStyle(PhotoPalette.brandBlue)
                .frame(maxWidth: .infinity)
                .frame(height: PhotoMetrics.addPhotosHeight)
                .background(Capsule().fill(PhotoPalette.background1))
            }
            .buttonStyle(.plain)

            if photos.isEmpty {
                Text("No photos yet".localized)
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                PhotoMosaicGrid(
                    photos: photos,
                    width: max(contentWidth - 44, 0),
                    onSelect: { photo in
                        let siblings = photo.reviewId.map { id in
                            photos.filter { $0.reviewId == id }
                        } ?? [photo]
                        lightbox = LightboxSelection(photos: siblings, initialID: photo.id)
                    }
                )
            }
        }
    }

    /// Opens the contribute flow on the facility the user is looking at,
    /// resuming an unfinished draft when there is one. Asks for sign-in
    /// FIRST — never after the wizard is already on screen.
    private func startReview() {
        guard auth.isSignedIn else {
            pendingAuthAction = .review
            showSignIn = true
            return
        }
        openReviewWizard()
    }

    private func openReviewWizard() {
        resumeScreenIndex = UnfinishedReviewStore.snapshot(for: place)?.screenIndex ?? 0
        showReviewWizard = true
    }

    private func openMaps() {
        let lat = place.coordinate.latitude
        let lng = place.coordinate.longitude
        let name = place.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "Place"
        if let url = URL(string: "maps://?daddr=\(lat),\(lng)&q=\(name)"),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func callWhatsApp() {
        let isIndo = languageManager.currentLanguage == .indonesia
        let message = isIndo
            ? "Halo! Saya ingin bertanya mengenai aksesibilitas di \(place.name)."
            : "Hello! I would like to inquire about accessibility facilities at \(place.name)."
        let encoded = message.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "https://wa.me/6281234567890?text=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    private func sharePlace() {
        let gradeText = (store.overallGrade ?? .noData).label
        // ONE string with the link inside, not [text, URL]: WhatsApp (and
        // several other share targets) take only the URL item when handed
        // both, so the message text silently vanished. Chat apps linkify the
        // https URL inside plain text on their own. The link redirects into
        // the app — see DeepLinkRouter and the place-link Edge Function.
        var shareText = "Check out \(place.name) — \(gradeText) on Puspadi Fellas!"
        if let url = DeepLinkRouter.shareURL(for: place) {
            shareText += "\n\(url.absoluteString)"
        }
        let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

/// Width of the content column, so the photo mosaic can size its tiles without
/// a GeometryReader inside the scroll view.
private struct DetailWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

#Preview {
    NavigationStack {
        MockPlaceDetailView(
            place: Place.fromSearchResult(
                name: "Park 23 Mall",
                category: "Shopping Mall",
                coordinate: CLLocationCoordinate2D(latitude: -8.741, longitude: 115.178)
            )
        )
        .environmentObject(LanguageManager.shared)
        .environmentObject(AuthSessionStore())
    }
}
