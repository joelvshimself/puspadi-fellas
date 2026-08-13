import MapKit
import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: DetailTab = .facilities
    @State private var isSaved = false

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
    /// The Apple Place Card ("widget") is presented as a sheet bound to this
    /// resolved MKMapItem — Apple's rich card (business photos, hours, and its
    /// own detailed map that renders building footprints / indoor floor plans
    /// where they exist). iOS 18+ only; on iOS 17 the button is hidden.
    @State private var detailMapItem: MKMapItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                topActions
                titleBlock
                if place.isLiveResult {
                    // Order: locator map -> accessibility grade -> directions
                    // up top (the decision-making info), then the street photo
                    // and reviews as supporting detail at the bottom.
                    FacilityMapHeader(coordinate: place.coordinate, name: place.name)
                    if #available(iOS 18.0, *) {
                        placeCardButton
                    }
                    accessibilityGradeSection
                    directionsButton

                    Text("Photo")
                        .font(.headline)
                    PlaceImageView(
                        coordinate: place.coordinate,
                        remoteImageURL: imageURL,
                        attribution: imageAttribution,
                        resolved: enrichResolved
                    )

                    liveReviewsSection
                } else {
                    // Mock sample places keep the original rating/summary card.
                    heroCard
                    tabBar
                    tabContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .background(Color(.systemBackground))
        .toolbar(.hidden, for: .navigationBar)
        .task(id: place.id) {
            await loadGrade()
        }
        .modifier(PlaceCardSheet(item: $detailMapItem))
    }

    @available(iOS 18.0, *)
    private var placeCardButton: some View {
        Button {
            Task { detailMapItem = await resolveMapItem() }
        } label: {
            Label("More place details", systemImage: "info.circle")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    /// Resolves the tapped place to a real MKMapItem (carrying Apple's place
    /// data, incl. photos) so the Place Card has something to show.
    private func resolveMapItem() async -> MKMapItem? {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = place.name
        request.region = MKCoordinateRegion(
            center: place.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        let response = try? await MKLocalSearch(request: request).start()
        return response?.mapItems.first
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

    @ViewBuilder
    private var accessibilityGradeSection: some View {
        if place.isLiveResult {
            VStack(alignment: .leading, spacing: 10) {
                Text("Accessibility Grade")
                    .font(.headline)

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

    private var topActions: some View {
        HStack(alignment: .top) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(Color(.secondarySystemBackground), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back")

            Spacer()

            VStack(alignment: .trailing, spacing: 10) {
                Button {
                    isSaved.toggle()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                        Text("Save")
                            .fontWeight(.semibold)
                    }
                    .font(.subheadline)
                    .foregroundStyle(isSaved ? Color.white : .primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(isSaved ? Color.accentColor : Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)

                ShareLink(item: "Check out \(place.name) on Puspadi Fellas") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(Color(.secondarySystemBackground), in: Circle())
                }
            }
        }
        .padding(.top, 8)
    }

    private var titleBlock: some View {
        Text(place.name)
            .font(.largeTitle.bold())
            .padding(.top, -4)
    }

    private var liveReviewsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reviews")
                .font(.headline)
            Text("No reviews yet — be the first to review this place's accessibility.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text(place.ratingLabel)
                    .font(.headline)
            }

            Text(place.summary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                // Directions mock — no navigation SDK wired.
            } label: {
                Label("Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
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
            facilitiesContent
        case .routes:
            Text(place.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        case .review:
            reviewsBox
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

    private var reviewsBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reviews Summary")
                .font(.headline)
            Text(place.reviewsSummary)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

/// Applies Apple's Place Card sheet on iOS 18+, and is a no-op on iOS 17
/// (the project's deployment target), so the feature degrades gracefully.
private struct PlaceCardSheet: ViewModifier {
    @Binding var item: MKMapItem?

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.mapItemDetailSheet(item: $item)
        } else {
            content
        }
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
    NavigationStack {
        PlaceDetailView(place: Place.samples[0])
    }
}
