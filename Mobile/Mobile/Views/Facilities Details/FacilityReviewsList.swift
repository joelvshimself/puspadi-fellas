import SwiftUI

struct FacilityReviewRow: View {
    let review: PlaceFacilityReview
    var onSelectPhoto: (FacilityPhoto) -> Void = { _ in }

    private var photos: [FacilityPhoto] {
        review.photoURLs.compactMap { url in
            guard let remote = URL(string: url) else { return nil }
            return FacilityPhoto(source: .remote(remote), reviewId: review.reviewId)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Community")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(review.bodyText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !review.providedList.isEmpty {
                (
                    Text("What Provided: ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    + Text(review.providedList)
                        .font(.subheadline)
                )
            }

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            Button { onSelectPhoto(photo) } label: {
                                FacilityPhotoImage(photo: photo, cornerRadius: 10)
                                    .frame(width: 88, height: 88)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private enum ReviewFilter: String, CaseIterable, Identifiable {
    case all
    case withPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "ALL"
        case .withPhotos: "WITH PHOTOS"
        }
    }

    var showsCamera: Bool { self == .withPhotos }
}

struct FacilityReviewsList: View {
    let reviews: [PlaceFacilityReview]

    @State private var selectedFilter: ReviewFilter = .all
    @State private var lightbox: LightboxSelection?

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    private var filtered: [PlaceFacilityReview] {
        switch selectedFilter {
        case .all: reviews
        case .withPhotos: reviews.filter { !$0.photoURLs.isEmpty }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReviewFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
            }

            if filtered.isEmpty {
                Text("No reviews match this filter")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, review in
                        if index > 0 { Divider() }
                        FacilityReviewRow(review: review) { photo in
                            let siblings = review.photoURLs.compactMap { url -> FacilityPhoto? in
                                guard let remote = URL(string: url) else { return nil }
                                return FacilityPhoto(source: .remote(remote), reviewId: review.reviewId)
                            }
                            lightbox = LightboxSelection(photos: siblings, initialID: photo.id)
                        }
                        .padding(.vertical, 14)
                    }
                }
            }
        }
        .fullScreenCover(item: $lightbox) { selection in
            FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
        }
    }

    private func filterChip(_ filter: ReviewFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button { selectedFilter = filter } label: {
            HStack(spacing: 6) {
                if filter.showsCamera {
                    Image(systemName: "camera").font(.caption)
                }
                Text(filter.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color(.systemGray5)))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FacilityReviewsList(reviews: [])
        .padding()
        .background(Color.white)
}
