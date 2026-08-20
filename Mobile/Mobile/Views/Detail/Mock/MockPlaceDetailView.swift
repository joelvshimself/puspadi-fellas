import CoreLocation
import SwiftUI

/// Primary place details screen — live grades, reviews, and facility cards.
struct MockPlaceDetailView: View {
    let place: Place

    @EnvironmentObject private var languageManager: LanguageManager
    @StateObject private var store: PlaceReviewStore

    @State private var isSaved = false
    @State private var heroPage: Int? = 0
    @State private var showReviewWizard = false
    @State private var resumeScreenIndex = 0
    @State private var facilityDestination: FacilityKind?

    private let heroHeight: CGFloat = 253

    init(place: Place) {
        self.place = place
        _store = StateObject(wrappedValue: PlaceReviewStore(place: place))
    }

    private var heroURLs: [URL] {
        store.reviewPhotos.compactMap(\.imageURL)
    }

    private var totalHeroCount: Int {
        max(1, (store.streetImageURL != nil ? 1 : 0) + heroURLs.count)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(spacing: 0) {
                    heroSection
                    contentSection
                        .background(Color(.systemBackground))
                }
            }
            .coordinateSpace(name: "heroScroll")

            topControls
        }
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .onAppear {
            let saveId = Place.canonicalPlaceId(from: place.coordinate)
            isSaved = SavedPlacesService.shared.isSaved(placeId: saveId)
        }
        .task {
            await store.load()
            store.startWatching()
        }
        .navigationDestination(item: $facilityDestination) { kind in
            NotReviewView(kind: kind, store: store, place: place)
                .enableSwipeBack()
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .fullScreenCover(isPresented: $showReviewWizard) {
            ContributeReviewFlowView(
                place: place,
                initialScreenIndex: resumeScreenIndex
            ) {
                showReviewWizard = false
                UnfinishedReviewStore.clear(for: place)
                Task { await store.load() }
            }
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

    private var topControls: some View {
        HStack {
            Spacer()

            HStack(spacing: 22) {
                Button { sharePlace() } label: {
                    Image(systemName: "square.and.arrow.up.fill")
                        .font(.system(size: 20, weight: .medium))
                }
                .buttonStyle(.plain)

                Button {
                    let saveId = Place.canonicalPlaceId(from: place.coordinate)
                    Task {
                        await SavedPlacesService.shared.toggleSave(placeId: saveId, place: place)
                        isSaved = SavedPlacesService.shared.isSaved(placeId: saveId)
                    }
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
                    place: place
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
        .padding(.bottom, 14)
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            placeInfoCard
                .padding(.horizontal, 22)
                .padding(.top, 16)

            Divider().padding(.top, 16)

            facilitiesHeader
                .padding(.horizontal, 22)
                .padding(.top, 16)

            let facilityCards = FacilityCardModel.cards(from: store)
            let listHeight = facilityCards.reduce(0) { sum, f in
                sum + FacilityCardHeight.height(for: f.state) + 12 // 12 = top(6) + bottom(6) insets
            }
            List {
                ForEach(facilityCards) { facility in
                    if let kind = facility.kind {
                        Button { facilityDestination = kind } label: {
                            FacilityCard(facility: facility)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 22, bottom: 6, trailing: 22))
                .listRowBackground(Color(.systemBackground))
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: listHeight)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    private var placeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Resolution has to be checked FIRST. `overallGrade` falls back to
            // `.noData` when there are no feature grades yet, so it is never
            // nil — which made the placeholder below unreachable and showed a
            // confident "NO DATA AVAILABLE" that then flipped to the real
            // grade. Malls hid this because the map had already cached theirs.
            if !store.enrichResolved {
                AccessibilityBadgePlaceholder()
            } else if let grade = store.overallGrade {
                AccessibilityBadge(grade: grade)
            }

            HStack {
                Text(place.name)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)
                Spacer()
                HStack(spacing: 8) {
                    circularActionButton(icon: "location.fill", action: openMaps)
                    circularActionButton(icon: "phone.fill", action: callWhatsApp)
                }
            }

            ctaRow
        }
    }

    @ViewBuilder
    private var ctaRow: some View {
        if UnfinishedReviewStore.hasUnfinished(for: place) {
            addReviewButton(title: "Unfinished review")
        } else if !store.hasAnyReviews() {
            VStack(alignment: .leading, spacing: 12) {
                Text("No one review this place yet")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                addReviewButton(title: "Be the first reviewer")
            }
        } else {
            addReviewButton(title: "Add New Review")
        }
    }

    private func addReviewButton(title: String) -> some View {
        Button {
            if let snap = UnfinishedReviewStore.snapshot(for: place) {
                resumeScreenIndex = snap.screenIndex
            } else {
                resumeScreenIndex = 0
            }
            showReviewWizard = true
        } label: {
            Text(title.localized)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private var facilitiesHeader: some View {
        HStack {
            Label {
                Text("Facilities".localized)
                    .font(.system(size: 18, weight: .semibold))
            } icon: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15))
            }
            .foregroundStyle(.primary)
            Spacer()
            if store.hasAnyReviews() {
                Text("\(store.facilityReviews.count) reviews")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color.mockSecondaryText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.mockSectionBackground, in: Capsule())
            }
        }
    }

    private func circularActionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.15), in: Circle())
        }
        .buttonStyle(.plain)
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
        let shareText = "Check out \(place.name) — \(gradeText) on Puspadi Fellas!"
        let av = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
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
    }
}
