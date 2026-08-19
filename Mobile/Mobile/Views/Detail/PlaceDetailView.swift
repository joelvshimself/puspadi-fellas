import MapKit
import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    /// Returns to the search results within the same bottom sheet (this view is
    /// now embedded in the sheet, not pushed as a separate page).
    var onBack: () -> Void = {}
    @State private var selectedTab: DetailTab = .facilities
    @State private var showReviewWizard = false
    @State private var showPhotos = false

    /// Live-fetched from place-accessibility — only meaningful for a real
    /// MKLocalSearch result (place.isLiveResult), never for the mock
    /// `Place.samples` used elsewhere in this demo.
    @State private var grade: [AccessibilityFeatureGrade] = []
    @State private var isLoadingGrade = false
    @State private var gradeLoadFailed = false
    /// Populated from the same enrich() response as the grade — a cached
    /// Mapillary photo URL for this place (nil if none), passed to PlaceImageView.
    @State private var imageURL: URL?
    @State private var imageAttribution: String?
    @State private var enrichResolved = false

    /// Community review photos from `place-review-photos` (facility-labeled).
    @State private var reviewPhotos: [ReviewPhoto] = []
    @State private var isLoadingReviewPhotos = false
    @State private var reviewPhotosLoadFailed = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topActions
                titleBlock
                // One layout for every place. A live search result fills it
                // from the `place-accessibility` response; the mock detail
                // screens on main keep their own canned fields.
                heroCard
                photosButton
                tabBar
                tabContent
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        // No opaque background — a ScrollView is transparent by default, so the
        // detail inherits the sheet's glassy material and matches the
        // search/peek states (same sheet, one look).
        .task(id: place.id) {
            async let gradeLoad: Void = loadGrade()
            async let photosLoad: Void = loadReviewPhotos()
            _ = await (gradeLoad, photosLoad)
            await watchPlaceReviews()
        }
        .fullScreenCover(isPresented: $showReviewWizard, onDismiss: {
            // A successful submit recomputes accessibility_grade() server-side
            // and may add new photos — drop the device enrich cache and refetch.
            Task {
                let key = PlaceCacheStore.key(
                    lat: place.coordinate.latitude,
                    lng: place.coordinate.longitude
                )
                await PlaceCacheStore.shared.remove(key)
                async let gradeLoad: Void = loadGrade()
                async let photosLoad: Void = loadReviewPhotos()
                _ = await (gradeLoad, photosLoad)
            }
        }) {
            ReviewWizardView(place: place) { showReviewWizard = false }
        }
        .fullScreenCover(isPresented: $showPhotos) {
            FacilityPhotosView(facilityName: place.name, onBack: { showPhotos = false })
        }
    }

    private func loadGrade() async {
        guard place.isLiveResult else { return }
        isLoadingGrade = true
        gradeLoadFailed = false
        defer {
            isLoadingGrade = false
            enrichResolved = true
        }
        do {
            let response = try await AccessibilityService.shared.enrich(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude,
                name: place.name
            )
            grade = response.grade ?? []
            imageURL = response.place?.imageUrl.flatMap(URL.init(string:))
            imageAttribution = response.place?.imageAttribution
        } catch {
            gradeLoadFailed = true
        }
    }

    private func loadReviewPhotos() async {
        guard place.isLiveResult else { return }
        isLoadingReviewPhotos = true
        reviewPhotosLoadFailed = false
        defer { isLoadingReviewPhotos = false }
        do {
            let response = try await ReviewService.shared.fetchReviewPhotos(
                lat: place.coordinate.latitude,
                lng: place.coordinate.longitude
            )
            reviewPhotos = response.photos
        } catch {
            reviewPhotosLoadFailed = true
        }
    }

    /// Live refresh while this sheet stays open: another device's review insert
    /// for the same `place_id` invalidates the enrich cache and reloads grade + photos.
    private func watchPlaceReviews() async {
        guard place.isLiveResult else { return }
        let placeId = PlaceCacheStore.key(
            lat: place.coordinate.latitude,
            lng: place.coordinate.longitude
        )
        for await _ in ReviewService.shared.watchReviewInserts(placeId: placeId) {
            await PlaceCacheStore.shared.remove(placeId)
            async let gradeLoad: Void = loadGrade()
            async let photosLoad: Void = loadReviewPhotos()
            _ = await (gradeLoad, photosLoad)
        }
    }

    /// TODO(backend): derived client-side from the per-feature rows as a
    /// placeholder — no overall-grade field exists on the backend response
    /// yet. Real logic should follow the Boolean Grading Matrix (E/V/T) once
    /// the backend computes it; this is a simple stand-in (any "no" →
    /// Not Accessible, all "yes" → Accessible, otherwise Partially Accessible).
    private var overallGrade: OverallAccessibility? {
        guard !grade.isEmpty else { return nil }
        if grade.contains(where: { $0.bestValue == "no" }) {
            return .notAccessible
        }
        if grade.allSatisfy({ $0.bestValue == "yes" }) {
            return .accessible
        }
        return .partiallyAccessible
    }

    @ViewBuilder
    private var accessibilityGradeSection: some View {
        if place.isLiveResult {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Accessibility Grade")
                        .font(.headline)
                    Spacer()
                    if let overallGrade {
                        Text(overallGrade.label)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(overallGrade.color.opacity(0.15), in: Capsule())
                            .foregroundStyle(overallGrade.color)
                    }
                }

                if isLoadingGrade {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 8)
                } else if gradeLoadFailed {
                    Text("Couldn't load accessibility data right now.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else if grade.isEmpty {
                    Text("No accessibility data yet for this place — be the first to check it.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(grade) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(color(for: item.bestValue))
                            Text(item.featureLabel)
                                .font(.subheadline.weight(.medium))
                            Spacer()
                            Text(item.valueLabel)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color(.separator), lineWidth: 1)
            )
        }
    }

    private func color(for bestValue: String) -> Color {
        switch bestValue {
        case "yes": .green
        case "no": .red
        case "limited": .orange
        default: .secondary
        }
    }

    // Just a back affordance to return to results — Save/Share removed for a
    // clean look (they can live elsewhere once those flows are built).
    private var topActions: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to results")

            Spacer()
        }
        .padding(.top, 4)
    }

    private var titleBlock: some View {
        Text(place.name)
            .font(.largeTitle.bold())
            .padding(.top, -4)
    }

    private var liveReviewsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Reviews")
                .font(.headline)
            Text("No reviews yet — be the first to review this place's accessibility.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Entry point into the crowdsourced review wizard (merged from the
            // review-flow branch). Lives here so live places can reach it too.
            Button {
                showReviewWizard = true
            } label: {
                Label("Write a Review", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }

    /// Entry point into the photos flow (Views/Photos/). Styled as the
    /// mockup's own "Add Photos" pill so the two screens read as one flow.
    private var photosButton: some View {
        Button {
            showPhotos = true
        } label: {
            HStack(spacing: PhotoMetrics.addPhotosSpacing) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 20))
                Text("Photos")
                    .font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .semibold))
            }
            .foregroundStyle(PhotoPalette.brandBlue)
            .frame(maxWidth: .infinity)
            .frame(height: PhotoMetrics.addPhotosHeight)
            .background(Capsule().fill(PhotoPalette.background1))
        }
        .buttonStyle(.plain)
    }

    private var directionsButton: some View {
        Button {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
            mapItem.name = place.name
            mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
        } label: {
            Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.white)
        }
        .buttonStyle(.plain)
    }

    /// TODO(backend): mock samples have no real grade data, so this maps
    /// the canned `ratingLabel` copy onto the same green/yellow/red badge
    /// as the live grade card, purely so the badge is visible in previews —
    /// not a real grading rule.
    private var mockOverallGrade: OverallAccessibility {
        if let g = place.grade {
            return g
        }
        switch place.ratingLabel {
        case "Accessible": return .accessible
        case "Moderately Accessible": return .partiallyAccessible
        case "Not Accessible": return .notAccessible
        default: return .noData
        }
    }

    /// The badge shown on the hero card: the real computed grade for a live
    /// place, the canned stand-in for a mock sample.
    private var displayGrade: OverallAccessibility? {
        place.isLiveResult ? overallGrade : mockOverallGrade
    }

    private var heroHeadline: String {
        guard place.isLiveResult else { return place.ratingLabel }
        if let overallGrade { return overallGrade.label }
        return isLoadingGrade ? "Checking accessibility…" : "Not graded yet"
    }

    /// For a live place this is derived from the actual per-feature grades
    /// rather than invented copy — there is no summary field on the backend.
    private var heroSummary: String {
        guard place.isLiveResult else { return place.summary }
        if isLoadingGrade { return "Loading accessibility data…" }
        if gradeLoadFailed { return "Couldn't load accessibility data right now." }
        guard !grade.isEmpty else {
            return "No accessibility data yet for this place — be the first to review it."
        }
        let byValue = Dictionary(grouping: grade, by: \.bestValue)
        var parts: [String] = []
        for (value, title) in [("yes", "Accessible"), ("limited", "Limited"), ("no", "Not accessible")] {
            if let rows = byValue[value], !rows.isEmpty {
                parts.append("\(title): \(rows.map(\.featureLabel).joined(separator: ", "))")
            }
        }
        return parts.joined(separator: " · ")
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(heroHeadline)
                    .font(.headline)
                Spacer()
                if let displayGrade {
                    Text(displayGrade.label)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(displayGrade.color.opacity(0.15), in: Capsule())
                        .foregroundStyle(displayGrade.color)
                }
            }

            Text(heroSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Real Maps hand-off for both — it only needs a coordinate.
            directionsButton
                .padding(.top, 4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }

    private var tabBar: some View {
        HStack(spacing: 24) {
            ForEach(DetailTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 6) {
                        Text(tab.title)
                            .font(.subheadline.weight(selectedTab == tab ? .semibold : .regular))
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                        Rectangle()
                            .fill(selectedTab == tab ? Color.primary : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .facilities:
            if place.isLiveResult {
                liveFacilitiesContent
            } else {
                facilitiesContent
            }
        case .routes:
            if place.isLiveResult {
                liveRoutesContent
            } else {
                Text(place.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .review:
            if place.isLiveResult {
                liveReviewsSection
            } else {
                reviewsBox
            }
        }
    }

    /// Real per-feature grades from the backend, plus the cached street photo.
    private var liveFacilitiesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            accessibilityGradeSection
            PlaceImageView(
                coordinate: place.coordinate,
                remoteImageURL: imageURL,
                attribution: imageAttribution,
                resolved: enrichResolved
            )
            // Community photos from `place-review-photos` (added on main).
            ReviewPhotosSection(
                photos: reviewPhotos,
                isLoading: isLoadingReviewPhotos,
                loadFailed: reviewPhotosLoadFailed,
                onRetry: {
                    Task { await loadReviewPhotos() }
                }
            )
        }
    }

    /// The locator map and a real Maps hand-off — a live place has no written
    /// route description on the backend, so none is invented here.
    private var liveRoutesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            FacilityMapHeader(coordinate: place.coordinate, name: place.name)
            directionsButton
        }
    }

    private var facilitiesContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                ForEach(place.facilitySymbols, id: \.self) { symbol in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(height: 64)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.title2)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Elevator")
                        .font(.headline)
                    Spacer()
                    Text("Route")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color(.tertiarySystemBackground)))
                }

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 14
                ) {
                    ForEach(place.elevatorDetails, id: \.label) { detail in
                        HStack(spacing: 10) {
                            Image(systemName: detail.symbol)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 28, height: 28)
                                .background(Circle().fill(Color(.tertiarySystemBackground)))
                            Text(detail.label)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            HStack(spacing: 10) {
                ForEach(place.gallerySymbols, id: \.self) { symbol in
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(place.accentColor.opacity(0.85))
                        .frame(height: 110)
                        .overlay {
                            Image(systemName: symbol)
                                .font(.title)
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                }
            }

            reviewsBox
        }
    }

    // NOTE: reviewsBox is shared by both the Facilities tab (as the trailing
    // card in facilitiesContent) and the Review tab (as its entire content)
    // — the "Write a Review" CTA below therefore surfaces in both places.
    // That's intentional (extra discoverability, harmless duplication) not
    // a bug — kept as one shared view rather than forking a near-duplicate.
    private var reviewsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reviews Summary")
                .font(.headline)
            Text(place.reviewsSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                showReviewWizard = true
            } label: {
                Label("Write a Review", systemImage: "square.and.pencil")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
            // A successful submit is followed by a grade refetch (see
            // fullScreenCover's onDismiss above), so the card updates.
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

private enum DetailTab: String, CaseIterable, Identifiable {
    case facilities
    case routes
    case review

    var id: String { rawValue }

    var title: String {
        switch self {
        case .facilities: "Facilities"
        case .routes: "Routes"
        case .review: "Review"
        }
    }
}

#Preview {
    PlaceDetailView(
        place: Place.fromSearchResult(
            name: "Preview Place",
            category: "Mall",
            coordinate: CLLocationCoordinate2D(latitude: -8.72, longitude: 115.17)
        )
    )
}


