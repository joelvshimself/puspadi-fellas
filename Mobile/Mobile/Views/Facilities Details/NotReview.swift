import CoreLocation
import SwiftUI

enum FacilityKind: String, CaseIterable, Identifiable {
    case elevator
    case toilet
    case entrance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elevator: "Elevator"
        case .toilet: "Toilets"
        case .entrance: "Entrances"
        }
    }

    var headline: String {
        switch self {
        case .elevator: "Elevator Available"
        case .toilet: "Accessible Toilet Available"
        case .entrance: "Accessible Entrance Available"
        }
    }

    var subtitle: String {
        switch self {
        case .elevator: "There's one accessible elevator in ground floor/"
        case .toilet: "There's one accessible toilet in ground floor/"
        case .entrance: "There's one accessible entrance in ground floor/"
        }
    }

    var imageName: String {
        switch self {
        case .elevator: "elevatorasset"
        case .toilet: "bathroomasset"
        case .entrance: "entranceasset"
        }
    }

    var providedItems: [(symbol: String, label: String)] {
        switch self {
        case .elevator:
            [
                ("door.left.hand.closed", "WIDE ENTRANCE"),
                ("hand.raised", "HANDLES"),
                ("button.programmable", "REACHABLE BUTTONS"),
            ]
        case .toilet:
            [
                ("figure.roll", "GRAB BARS"),
                ("sink", "LOWERED SINK"),
                ("bell", "EMERGENCY CORD"),
            ]
        case .entrance:
            [
                ("door.left.hand.closed", "WIDE ENTRANCE"),
                ("road.lanes", "RAMP"),
                ("hand.raised", "RAIL"),
            ]
        }
    }

    var singularName: String {
        switch self {
        case .elevator: "elevator"
        case .toilet: "toilet"
        case .entrance: "entrance"
        }
    }

    var unavailableSubtitle: String {
        "This place doesn’t has an accessible \(singularName) yet."
    }

    var foundPrompt: String {
        "Found accessible \(singularName)?"
    }

    var reviewedHeadline: String {
        switch self {
        case .elevator: "Accessible Elevator"
        case .toilet: "Accessible Toilet"
        case .entrance: "Accessible Entrance"
        }
    }

    var reviewedSubtitle: String {
        switch self {
        case .elevator: "People mostly used the elevator near the lobby."
        case .toilet: "People mostly used the accessible toilet on the ground floor."
        case .entrance: "People mostly accessed through the lobby and has automatic door."
        }
    }

    var reviewedProvidedItems: [(symbol: String, label: String)] {
        switch self {
        case .elevator:
            [
                ("door.left.hand.closed", "WIDE DOOR"),
                ("hand.raised", "HANDLES"),
                ("button.programmable", "REACHABLE BUTTONS"),
            ]
        case .toilet:
            [
                ("figure.roll", "GRAB BARS"),
                ("sink", "LOWERED SINK"),
                ("bell", "EMERGENCY CORD"),
            ]
        case .entrance:
            [
                ("figure.roll", "RAMP"),
                ("hand.raised", "HANDRAIL"),
                ("door.left.hand.closed", "AUTOMATIC DOORS"),
                ("door.left.hand.open", "MANUAL DOORS"),
                ("person.badge.shield.checkmark", "SECURITY ASSISTANCE"),
            ]
        }
    }

    var reviewNotes: [String] {
        switch self {
        case .elevator:
            ["Hard to find", "Buttons too high", "No floor announcements"]
        case .toilet:
            ["Hard to find", "No grab bars on both sides", "Sink too high"]
        case .entrance:
            ["Hard to find", "No drop off ramps", "No Rails"]
        }
    }

    var reviewBody: String {
        switch self {
        case .elevator:
            "The elevator is quite hard to find. When I went there, the buttons were high and there were no floor announcements, so I had to ask for help."
        case .toilet:
            "The accessible toilet is quite hard to find. When I went there, grab bars were only on one side and the sink was too high."
        case .entrance:
            "The entrance is quite hard to find. When I went there, there's a lot of stairs and it is very hard too see the signage and need to ask the security."
        }
    }

    var reviewProvidedList: String {
        switch self {
        case .elevator: "Wide Door, Handles, Reachable Buttons"
        case .toilet: "Grab Bars, Lowered Sink, Emergency Cord"
        case .entrance: "Ramp, Handrail, Automatic Doors, Manual Doors"
        }
    }
}

enum FacilityOverviewState {
    /// Available, no community reviews yet.
    case empty
    /// Available with community notes, current user has not reviewed.
    case community
    /// Current user has already submitted a review.
    case reviewed
    case unavailable

    /// Behind the segmented control and hero card.
    var headerBackground: Color {
        .white
    }

    /// Behind “What provided” and the rest of overview.
    var bodyBackground: Color {
        switch self {
        case .empty:
            Color(red: 248 / 255, green: 249 / 255, blue: 251 / 255)
        case .unavailable:
            Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
        case .community:
            Color(red: 232 / 255, green: 238 / 255, blue: 246 / 255)
        case .reviewed:
            Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
        }
    }
}

struct NotReviewView: View {
    let kind: FacilityKind
    @ObservedObject var store: PlaceReviewStore
    var place: Place

    @State private var selectedTab: FacilityDetailTab = .overview
    @State private var isComposingPhotos = false
    @State private var showContributeFlow = false

    private var state: FacilityOverviewState { store.overviewState(for: kind) }
    private var reviews: [PlaceFacilityReview] { store.reviews(for: kind) }

    var body: some View {
        VStack(spacing: 0) {
            if selectedTab != .photos || !isComposingPhotos {
                Picker("Section", selection: $selectedTab) {
                    ForEach(FacilityDetailTab.allCases) { tab in
                        Text(tab.title.uppercased()).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)
                .background(chromeBackground)
            }

            if selectedTab == .photos {
                FacilityPhotosView(
                    facilityName: kind.title,
                    photos: store.facilityPhotos(for: kind),
                    place: place,
                    facilityKind: kind,
                    selectedTab: $selectedTab,
                    showsChrome: false,
                    onBack: { selectedTab = .overview },
                    onComposingChanged: { isComposingPhotos = $0 },
                    onPhotosChanged: { Task { await store.load() } }
                )
            } else {
                overviewAndReviews
            }
        }
        .background {
            Group {
                if selectedTab == .overview, state == .unavailable {
                    Color(red: 242 / 255, green: 244 / 255, blue: 247 / 255)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    chromeBackground
                }
            }
        }
        .toolbarBackground(.white, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .navigationTitle(kind.title)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedTab) { _, tab in
            if tab != .photos {
                isComposingPhotos = false
            }
        }
        .fullScreenCover(isPresented: $showContributeFlow) {
            ContributeReviewFlowView(place: place, startingFacility: kind) {
                showContributeFlow = false
                Task {
                    await PlaceCacheStore.shared.remove(store.placeId)
                    await store.load()
                }
            }
        }
    }

    private var overviewAndReviews: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    VStack(alignment: .leading, spacing: 20) {
                        if selectedTab == .overview {
                            overviewHero
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, selectedTab == .overview ? 20 : 0)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(chromeBackground)

                    Group {
                        switch selectedTab {
                        case .overview:
                            overviewLower
                        case .reviews:
                            if reviews.isEmpty {
                                emptyCard(message: "No one review this place yet")
                            } else {
                                FacilityReviewsList(reviews: reviews)
                            }
                        case .photos:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    .background(contentBackground)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
    }

    private var chromeBackground: Color {
        .white
    }

    private var contentBackground: Color {
        if selectedTab == .reviews { return .white }
        if selectedTab == .photos { return Color(.systemBackground) }
        return state.bodyBackground
    }

    @ViewBuilder
    private var overviewHero: some View {
        switch state {
        case .empty:
            FacilityHeroCard(kind: kind, headline: kind.headline, subtitle: kind.subtitle) {
                Text("Google Maps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
            }
        case .unavailable:
            FacilityHeroCard(kind: kind, headline: "Not Available", subtitle: kind.unavailableSubtitle) {
                FacilitySourceProof()
            }
        case .community, .reviewed:
            FacilityHeroCard(
                kind: kind,
                headline: kind.reviewedHeadline,
                subtitle: kind.reviewedSubtitle
            ) {
                FacilitySourceProof()
            }
        }
    }

    @ViewBuilder
    private var overviewLower: some View {
        switch state {
        case .empty:
            emptyLower
        case .unavailable:
            unavailableLower
        case .community:
            FacilityReviewedOverview(
                kind: kind,
                store: store,
                showsUserReview: false,
                place: place,
                onOpenReviews: { selectedTab = .reviews },
                onBeFirstReviewer: { showContributeFlow = true }
            )
        case .reviewed:
            FacilityReviewedOverview(
                kind: kind,
                store: store,
                showsUserReview: true,
                place: place,
                onOpenReviews: { selectedTab = .reviews },
                onBeFirstReviewer: { showContributeFlow = true }
            )
        }
    }

    private var emptyLower: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "What provided") {
                FlowRow(spacing: 10) {
                    ForEach(kind.providedItems, id: \.label) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.caption)
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5), in: Capsule())
                    }
                }
            }

            NotesFromReviewsSection(
                snippets: [],
                onBeFirstReviewer: { showContributeFlow = true },
                onOpenReviews: { selectedTab = .reviews }
            )
        }
    }

    private var unavailableLower: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(kind.foundPrompt)
                .font(.title3.bold())

            Button {
                showContributeFlow = true
            } label: {
                Text("Add New Review")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
        }
    }

    private func emptyCard(message: String) -> some View {
        Text(message)
            .font(.subheadline)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
    }
}

#Preview("Elevator") {
    NavigationStack {
        NotReviewView(
            kind: .elevator,
            store: PlaceReviewStore(place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))),
            place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))
        )
    }
}

#Preview("Toilet") {
    NavigationStack {
        NotReviewView(
            kind: .toilet,
            store: PlaceReviewStore(place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))),
            place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))
        )
    }
}

#Preview("Entrance") {
    NavigationStack {
        NotReviewView(
            kind: .entrance,
            store: PlaceReviewStore(place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))),
            place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0))
        )
    }
}

struct FacilityHeroCard<Footer: View>: View {
    let kind: FacilityKind
    let headline: String
    let subtitle: String
    @ViewBuilder var footer: () -> Footer

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(kind.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 88, height: 88)

            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                footer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.systemGray5))
        )
    }
}

struct FacilitySourceProof: View {
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: -10) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: "person.crop.circle.fill")
                        .font(.title2)
                        .foregroundStyle([Color.orange, .blue, .pink][index])
                        .background(Circle().fill(Color.white))
                }
            }
            Text("+10")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Google Maps +2")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color(.systemGray4).opacity(0.55), in: Capsule())
        }
    }
}
