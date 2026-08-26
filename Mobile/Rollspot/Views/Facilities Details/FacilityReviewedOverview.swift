import SwiftUI

struct FacilityReviewedOverview: View {
    let kind: FacilityKind
    @ObservedObject var store: PlaceReviewStore
    var showsUserReview: Bool = true
    var place: Place
    var onOpenReviews: () -> Void
    var onBeFirstReviewer: () -> Void

    @State private var lightbox: LightboxSelection?
    @State private var showContributeFlow = false

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    private var reviews: [PlaceFacilityReview] { store.reviews(for: kind) }
    private var latestTags: [String] { reviews.first?.providedTags ?? [] }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "What provided") {
                if latestTags.isEmpty {
                    Text("No structured tags yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlowRow(spacing: 10) {
                        ForEach(latestTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray5), in: Capsule())
                        }
                    }
                }
            }

            NotesFromReviewsSection(
                snippets: store.noteSnippets(for: kind),
                hasReviews: store.hasReviews(for: kind),
                onOpenReviews: onOpenReviews
            )

            if showsUserReview, let latest = reviews.first {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Latest Review")
                            .font(.headline)
                        Spacer()
                        Button("Add New Review") { showContributeFlow = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    FacilityReviewRow(review: latest) { photo in
                        let siblings = latest.photoURLs.enumerated().compactMap { index, urlString -> FacilityPhoto? in
                            guard let remote = URL(string: urlString) else { return nil }
                            return FacilityPhoto(
                                id: .stable(from: "\(index)|\(urlString)"),
                                source: .remote(remote),
                                reviewId: latest.reviewId,
                                caption: latest.caption(forPhotoAt: index)
                            )
                        }
                        lightbox = LightboxSelection(photos: siblings, initialID: photo.id)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                }
            } else if !showsUserReview {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Find something different?")
                        .font(.title3.bold())
                    Button { showContributeFlow = true } label: {
                        Text("Add New Review")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(item: $lightbox) { selection in
            FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
        }
        .fullScreenCover(isPresented: $showContributeFlow) {
            ContributeReviewFlowView(
                place: place,
                onSubmitted: { submission in
                    if let canonicalId = submission.placeId {
                        store.adoptPlaceId(canonicalId)
                    }
                }
            ) {
                showContributeFlow = false
                Task {
                    await PlaceCacheStore.shared.remove(store.placeId)
                    await store.load()
                }
            }
        }
    }

    private func section<Content: View>(
        title: String,
        contentInsets: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
                .padding(contentInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                )
        }
    }
}

#Preview {
    ScrollView {
        FacilityReviewedOverview(
            kind: .entrance,
            store: PlaceReviewStore(
                place: Place.fromSearchResult(
                    name: "Preview",
                    category: "Mall",
                    coordinate: .init(latitude: 0, longitude: 0)
                )
            ),
            place: Place.fromSearchResult(name: "Preview", category: "Mall", coordinate: .init(latitude: 0, longitude: 0)),
            onOpenReviews: {},
            onBeFirstReviewer: {}
        )
        .padding()
    }
    .background(Color(.systemGroupedBackground))
}
