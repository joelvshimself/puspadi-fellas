import CoreLocation
import SwiftUI

/// Demo "Place Details" screen matching the Figma mockup (Default / No
/// Review Yet / Reviewed states). Mock data only (MockData), no backend
/// calls — kept fully separate from the live, MapKit-backed
/// `PlaceDetailView`. Reached via SavedView's demo entry point.
struct MockPlaceDetailView: View {
    /// A real place when this screen is opened from search; nil for
    /// SavedView's demo entry point, which keeps the MockData fixtures.
    var place: Place? = nil
    /// Set when presented inside the home sheet, where `dismiss()` would
    /// close the whole sheet rather than go back to the results.
    var onBack: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var demoState: PlaceDetailDemoState = .notYetReviewed
    /// Live accessibility grade for `place`, from `place-accessibility`.
    @State private var liveGrade: [AccessibilityFeatureGrade] = []
    @State private var isLoadingGrade = false
    /// Hero carousel sources for a real place: the cached Mapillary street
    /// photo first, then community review photos from `place-review-photos`.
    @State private var heroURLs: [URL] = []
    @State private var heroAttribution: String?
    @State private var streetImageURL: URL?
    @State private var enrichResolved = false
    @State private var isSaved = false
    @State private var heroPage = 0
    @State private var showReviewWizard = false

    /// Reused by both "Add New Review"/"Be the first reviewer" here and My
    /// Review's "Update Review" — same throwaway-`Place` pattern as
    /// `AnalysingView`'s standalone demo entry, since `ReviewWizardView`
    /// needs a real `Place` and there's no backend place behind this mock.
    private var wizardPlace: Place {
        if let place { return place }
        return Place.fromSearchResult(
            name: MockData.placeName,
            category: "Mall",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
    }

    /// Demo-only multi-photo hero carousel — duplicates the 2 real place
    /// PNGs we have out to 5 slides purely so paging/indicator behavior is
    /// testable (no real multi-photo backend yet).
    private let heroImages = [
        "Park23 Header picture", "Park23 Image",
        "Park23 Header picture", "Park23 Image",
        "Park23 Header picture",
    ]

    private let heroHeight: CGFloat = 253

    var body: some View {
        // topControls lives OUTSIDE the ScrollView, in this ZStack, so it
        // stays pinned on screen at a fixed position while everything else
        // scrolls underneath it — like Airbnb/Zillow-style listing screens,
        // rather than scrolling away with the hero photo.
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
        // System background, not black — the stretchy hero already covers
        // top overscroll by growing itself (see heroSection), so this is
        // only ever seen at the BOTTOM on overscroll past the content,
        // where it should read as normal page background, not a black gap.
        .background(Color(.systemBackground))
        .ignoresSafeArea(edges: .top)
        .task(id: place?.id) { await loadLiveGrade() }
        .task(id: place?.id) { await watchReviews() }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showReviewWizard) {
            ReviewWizardView(place: wizardPlace) {
                showReviewWizard = false
                // Mock-only stand-in for a real submit: reflect it in the
                // demo state so "Add New Review" visibly connects to
                // something instead of being a dead-end sheet.
                demoState = .reviewedByMe
            }
        }
    }

    // MARK: Hero

    /// Classic "stretchy header": reads its own scroll offset via
    /// GeometryReader, and when pulled down past the top (minY > 0) grows
    /// the hero taller by that amount and shifts it up to compensate — so
    /// the photo fills the overscroll instead of leaving a gap behind it.
    private var heroSection: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("heroScroll")).minY
            let stretch = max(0, minY)
            let height = heroHeight + stretch

            ZStack(alignment: .top) {
                TabView(selection: $heroPage) {
                    if let place {
                        // Page 0 is the street photo: PlaceImageView already
                        // walks Mapillary -> Look Around -> map snapshot.
                        PlaceImageView(
                            coordinate: place.coordinate,
                            remoteImageURL: streetImageURL,
                            attribution: heroAttribution,
                            resolved: enrichResolved,
                            // Full-bleed: the hero stretches with overscroll and
                            // sits under the status bar, so it takes the paged
                            // height and squares off its corners.
                            height: height,
                            cornerRadius: 0
                        )
                        .frame(width: geo.size.width, height: height)
                        .clipped()
                        .tag(0)

                        // Then whatever the community has contributed.
                        ForEach(heroURLs.indices, id: \.self) { index in
                            AsyncImage(url: heroURLs[index]) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color(.secondarySystemBackground).overlay { ProgressView() }
                                }
                            }
                            .frame(width: geo.size.width, height: height)
                            .clipped()
                            .tag(index + 1)
                        }
                    } else {
                        // SavedView's demo entry keeps the bundled fixtures.
                        ForEach(heroImages.indices, id: \.self) { index in
                            Image(heroImages[index])
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: height)
                                .clipped()
                                .tag(index)
                        }
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
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

    private var topControls: some View {
        HStack {
            // The nav bar is hidden (custom hero header instead), so this
            // circular button is the real back affordance — `dismiss()`
            // pops this NavigationStack push same as the system back button.
            Button {
                if let onBack { onBack() } else { dismiss() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.black)
                    .frame(width: 44, height: 44)
                    .background {
                        Circle().fill(Color.white.opacity(0.55))
                        Circle().fill(.ultraThinMaterial)
                    }
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 22) {
                Image(systemName: "square.and.arrow.up.fill")
                    .font(.system(size: 20, weight: .medium))
                Button {
                    isSaved.toggle()
                } label: {
                    Image(systemName: "bookmark.fill")
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
        HStack {
            HStack(spacing: 4) {
                ForEach(heroImages.indices, id: \.self) { index in
                    if index == heroPage {
                        Capsule().fill(.white).frame(width: 27, height: 4)
                    } else {
                        Circle().fill(.white.opacity(0.5)).frame(width: 4, height: 4)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: heroPage)

            Spacer()

            NavigationLink {
                MockGalleryView()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("GALLERY")
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

    // MARK: Content

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            placeInfoCard
                .padding(.horizontal, 22)
                .padding(.top, 16)

            Divider()
                .padding(.top, 16)

            facilitiesHeader
                .padding(.horizontal, 22)
                .padding(.top, 16)

            // Tapping a card opens the real facility-detail screen from
            // main (Views/Facilities Details/NotReview.swift) — FacilityKind
            // matches MockFacility.key 1:1 ("entrance"/"elevator"/"toilet").
            VStack(spacing: 12) {
                ForEach(MockData.facilities) { facility in
                    if let kind = FacilityKind(rawValue: facility.key) {
                        NavigationLink {
                            NotReviewView(kind: kind, state: facilityOverviewState)
                        } label: {
                            FacilityCard(facility: facility)
                        }
                        .buttonStyle(.plain)
                    } else {
                        FacilityCard(facility: facility)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
    }

    /// Maps this mock screen's 3-state demo toggle onto the facility
    /// screen's own state enum, so tapping a card lands on a facility
    /// detail that's consistent with what Place Details is showing.
    private var facilityOverviewState: FacilityOverviewState {
        switch demoState {
        case .noReview: .empty
        case .notYetReviewed: .community
        case .reviewedByMe: .reviewed
        }
    }

    private var placeInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let badgeGrade {
                AccessibilityBadge(grade: badgeGrade)
            }

            HStack {
                Text(place?.name ?? MockData.placeName)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 8) {
                    circularActionButton(icon: "location.fill")
                    circularActionButton(icon: "phone.fill")
                }
            }

            ctaRow
        }
    }

    /// Which of the 4 badge states this demo state shows — `nil` hides the
    /// badge entirely (matches the "No Review Yet" mockup, which has no
    /// badge at all rather than a "No Data Available" one).
    private var badgeGrade: OverallAccessibility? {
        // A real place is graded from the backend rows, not the demo toggle.
        if place != nil {
            guard !liveGrade.isEmpty else { return isLoadingGrade ? nil : .noData }
            if liveGrade.contains(where: { $0.bestValue == "no" }) { return .notAccessible }
            if liveGrade.allSatisfy({ $0.bestValue == "yes" }) { return .accessible }
            return .partiallyAccessible
        }
        switch demoState {
        case .noReview: return nil
        case .notYetReviewed, .reviewedByMe: return .accessible
        }
    }

    private func loadLiveGrade() async {
        guard let place else { return }
        isLoadingGrade = true
        defer { isLoadingGrade = false }

        async let enriched = try? await AccessibilityService.shared.enrich(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude,
            name: place.name
        )
        async let reviewPhotos = try? await ReviewService.shared.fetchReviewPhotos(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        let (response, photos) = await (enriched, reviewPhotos)

        liveGrade = response?.grade ?? []
        heroAttribution = response?.place?.imageAttribution

        // The street photo is rendered by PlaceImageView (Mapillary, then Look
        // Around, then a map snapshot); these are the community review photos
        // that page after it.
        streetImageURL = response?.place?.imageUrl.flatMap(URL.init(string:))
        heroURLs = (photos?.photos ?? []).compactMap(\.imageURL)
        enrichResolved = true
    }

    /// Realtime: a new review for this place recomputes the grade server-side
    /// and may add photos, so refetch when one lands.
    private func watchReviews() async {
        guard let place else { return }
        let key = PlaceCacheStore.key(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        for await _ in ReviewService.shared.watchReviewInserts(placeId: key) {
            await PlaceCacheStore.shared.remove(key)
            await loadLiveGrade()
        }
    }

    private func circularActionButton(icon: String) -> some View {
        Image(systemName: icon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color.accentColor)
            .frame(width: 40, height: 40)
            .background(Color.accentColor.opacity(0.15), in: Circle())
    }

    @ViewBuilder
    private var ctaRow: some View {
        switch demoState {
        case .noReview:
            VStack(alignment: .leading, spacing: 12) {
                Text("No one review this place yet")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                addReviewButton(title: "Be the first reviewer")
            }
        case .notYetReviewed:
            addReviewButton(title: "Add New Review")
        case .reviewedByMe:
            NavigationLink {
                MockMyReviewView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.bubble.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Thank you for the review!")
                        .font(.system(size: 15))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.mockSectionBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    private func addReviewButton(title: String) -> some View {
        Button {
            showReviewWizard = true
        } label: {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(Color.accentColor, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private let reviewerTints: [Color] = [.orange, .indigo, .pink]
    // "+10" / "Google Maps +2" pills use the shared Figma token
    // (Color.mockSectionBackground / .mockSecondaryText).
    private let pillBackground = Color.mockSectionBackground
    private let pillText = Color.mockSecondaryText

    private var facilitiesHeader: some View {
        HStack {
            Label {
                Text("Facilities")
                    .font(.system(size: 18, weight: .semibold))
            } icon: {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 15))
            }
            .foregroundStyle(.primary)

            Spacer()

            if demoState != .noReview {
                // Avatars + "+10" as one tight, connected unit (matches the
                // design's single pill) rather than two elements separated
                // by the outer HStack's default spacing.
                HStack(spacing: 4) {
                    HStack(spacing: -14) {
                        // No real reviewer photo assets in the project yet —
                        // filled person glyphs with distinct tints stand in
                        // for the design's face photos so the cluster
                        // doesn't read as flat/blank circles. Swap for real
                        // avatar images (Image("...")) once those exist.
                        ForEach(Array(reviewerTints.enumerated()), id: \.offset) { _, tint in
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 22, height: 22)
                                .foregroundStyle(tint)
                                .background(Color(.systemBackground), in: Circle())
                                .overlay(Circle().stroke(Color(.systemBackground), lineWidth: 1.5))
                        }
                    }
                    Text("+10")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(pillText)
                }
                .padding(.leading, -30)
                .padding(.trailing, 6)
                .padding(.vertical, 0)
                .background(pillBackground, in: Capsule())
            }

            Text("Google Maps +2")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(pillText)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(pillBackground, in: Capsule())
        }
    }
}

#Preview("No Review") {
    NavigationStack {
        MockPlaceDetailView(demoState: .noReview)
    }
}

#Preview("Default") {
    NavigationStack {
        MockPlaceDetailView(demoState: .notYetReviewed)
    }
}

#Preview("Reviewed") {
    NavigationStack {
        MockPlaceDetailView(demoState: .reviewedByMe)
    }
}

private extension MockPlaceDetailView {
    init(demoState: PlaceDetailDemoState) {
        self.init()
        _demoState = State(initialValue: demoState)
    }
}
