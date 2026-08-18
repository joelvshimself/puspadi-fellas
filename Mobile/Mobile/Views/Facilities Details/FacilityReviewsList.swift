import SwiftUI

struct FacilityReviewRow: View {
    let bodyText: String
    let providedList: String
    var photos: [FacilityPhoto] = FacilityPhoto.reviewThumbnails
    var onSelectPhoto: (FacilityPhoto) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                Text("Aarief M.")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Jan 2025")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(bodyText)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            (
                Text("What Provided: ")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.secondary)
                + Text(providedList)
                    .font(.subheadline)
            )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos) { photo in
                        Button {
                            onSelectPhoto(photo)
                        } label: {
                            FacilityPhotoImage(photo: photo, cornerRadius: 10)
                                .frame(width: 88, height: 88)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Review photo")
                    }
                }
            }
        }
    }
}

private enum ReviewFilter: String, CaseIterable, Identifiable {
    case all
    case withPhotos
    case hardToFind
    case security

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "ALL"
        case .withPhotos: "WITH PHOTOS"
        case .hardToFind: "HARD TO FIND (10)"
        case .security: "SECURITY"
        }
    }

    var showsCamera: Bool { self == .withPhotos }
}

struct FacilityReviewsList: View {
    let kind: FacilityKind

    @State private var selectedFilter: ReviewFilter = .all
    @State private var selectedPhoto: FacilityPhoto?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(ReviewFilter.allCases) { filter in
                        filterChip(filter)
                    }
                }
            }

            VStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { index in
                    if index > 0 {
                        Divider()
                    }
                    FacilityReviewRow(
                        bodyText: kind.reviewBody,
                        providedList: kind.reviewProvidedList,
                        onSelectPhoto: { selectedPhoto = $0 }
                    )
                    .padding(.vertical, 14)
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FacilityPhotoDetailView(photo: photo)
        }
    }

    private func filterChip(_ filter: ReviewFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button {
            selectedFilter = filter
        } label: {
            HStack(spacing: 6) {
                if filter.showsCamera {
                    Image(systemName: "camera")
                        .font(.caption)
                }
                Text(filter.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule().fill(isSelected ? Color.accentColor : Color(.systemGray5))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FacilityReviewsList(kind: .entrance)
        .padding()
        .background(Color.white)
}
