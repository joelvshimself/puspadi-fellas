import SwiftUI

/// Horizontal gallery of community review photos for a place, each tagged
/// with its facility label (Lobby / Basement / Elevator / Toilet).
struct ReviewPhotosSection: View {
    let photos: [ReviewPhoto]
    var isLoading: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review Photos")
                .font(.headline)

            if isLoading && photos.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
            } else if photos.isEmpty {
                Text("No review photos yet for this place.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(photos) { photo in
                            ReviewPhotoThumbnail(photo: photo)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), lineWidth: 1)
        )
    }
}

private struct ReviewPhotoThumbnail: View {
    let photo: ReviewPhoto

    @State private var image: UIImage?
    @State private var finishedLoading = false

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if !finishedLoading {
                    ZStack {
                        Color(.secondarySystemBackground)
                        ProgressView()
                    }
                } else {
                    ZStack {
                        Color(.secondarySystemBackground)
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(width: 112, height: 112)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Text(photo.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .task(id: photo.url) {
            await load()
        }
    }

    private func load() async {
        finishedLoading = false
        defer { finishedLoading = true }
        guard let url = photo.imageURL else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        image = UIImage(data: data)
    }
}
