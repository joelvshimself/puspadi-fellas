import SwiftUI

/// Horizontal gallery of community review photos clustered by facility.
/// One tile per label (Lobby / Basement / Elevator / Toilet); tap opens a
/// detail gallery of every photo in that cluster.
struct ReviewPhotosSection: View {
    let photos: [ReviewPhoto]
    var isLoading: Bool = false

    @State private var selectedCluster: ReviewPhotoCluster?

    private var clusters: [ReviewPhotoCluster] {
        ReviewPhotoCluster.grouped(from: photos)
    }

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
                        ForEach(clusters) { cluster in
                            Button {
                                selectedCluster = cluster
                            } label: {
                                ReviewPhotoClusterTile(cluster: cluster)
                            }
                            .buttonStyle(.plain)
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
        .sheet(item: $selectedCluster) { cluster in
            ReviewPhotoFacilityDetailView(cluster: cluster)
        }
    }
}

struct ReviewPhotoCluster: Identifiable, Hashable {
    let facility: String
    let label: String
    let photos: [ReviewPhoto]

    var id: String { facility }
    var cover: ReviewPhoto? { photos.first }
    var count: Int { photos.count }

    /// Stable facility order: lobby → basement → elevator → toilet → other.
    static func grouped(from photos: [ReviewPhoto]) -> [ReviewPhotoCluster] {
        let order = ["lobby", "basement", "elevator", "toilet"]
        var buckets: [String: [ReviewPhoto]] = [:]
        var labels: [String: String] = [:]

        for photo in photos {
            buckets[photo.facility, default: []].append(photo)
            if labels[photo.facility] == nil {
                labels[photo.facility] = photo.label
            }
        }

        let known = order.compactMap { key -> ReviewPhotoCluster? in
            guard let list = buckets.removeValue(forKey: key), !list.isEmpty else { return nil }
            return ReviewPhotoCluster(
                facility: key,
                label: labels[key] ?? key.capitalized,
                photos: list
            )
        }

        let rest = buckets.keys.sorted().compactMap { key -> ReviewPhotoCluster? in
            guard let list = buckets[key], !list.isEmpty else { return nil }
            return ReviewPhotoCluster(
                facility: key,
                label: labels[key] ?? key.capitalized,
                photos: list
            )
        }

        return known + rest
    }
}

private struct ReviewPhotoClusterTile: View {
    let cluster: ReviewPhotoCluster

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                if let cover = cluster.cover {
                    ReviewRemoteThumbnail(urlString: cover.url)
                } else {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                        .frame(width: 112, height: 112)
                }

                if cluster.count > 1 {
                    Text("\(cluster.count)")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.55), in: Capsule())
                        .padding(6)
                }
            }

            Text(cluster.label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct ReviewPhotoFacilityDetailView: View {
    let cluster: ReviewPhotoCluster
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(cluster.photos) { photo in
                        ReviewRemoteThumbnail(urlString: photo.url, size: nil)
                            .frame(maxWidth: .infinity)
                            .frame(height: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(20)
            }
            .navigationTitle(cluster.label)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

/// Shared remote JPEG loader used by cluster tiles and the facility gallery.
struct ReviewRemoteThumbnail: View {
    let urlString: String
    var size: CGFloat? = 112

    @State private var image: UIImage?
    @State private var finishedLoading = false

    var body: some View {
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
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .task(id: urlString) {
            await load()
        }
    }

    private func load() async {
        finishedLoading = false
        defer { finishedLoading = true }
        guard let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return }
        image = UIImage(data: data)
    }
}
