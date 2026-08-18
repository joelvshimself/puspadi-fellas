import SwiftUI

/// Demo "Gallery" screen — ALL/ENTRANCE/ELEVATOR/TOILET filter over the
/// mock Park23 Mall photo set. Mock data only, reached from
/// MockPlaceDetailView's "GALLERY" chip.
struct MockGalleryView: View {
    private enum Filter: String, CaseIterable {
        case all = "ALL"
        case entrance = "ENTRANCE"
        case elevator = "ELEVATOR"
        case toilet = "TOILET"

        var facilityKey: String? {
            switch self {
            case .all: nil
            case .entrance: "entrance"
            case .elevator: "elevator"
            case .toilet: "toilet"
            }
        }
    }

    @State private var selectedFilter: Filter = .all
    @State private var showAddPhotos = false

    private var filteredPhotos: [MockPhoto] {
        guard let key = selectedFilter.facilityKey else { return MockData.photos }
        return MockData.photos.filter { $0.facility == key }
    }

    var body: some View {
        VStack(spacing: 0) {
            FilterSegmentedControl(
                options: Filter.allCases,
                label: \.rawValue,
                selection: $selectedFilter
            )
            .padding(.horizontal, 12)
            .padding(.top, 12)

            addPhotosButton
                .padding(.horizontal, 12)
                .padding(.vertical, 16)

            ScrollView(showsIndicators: false) {
                photoGrid
                    .padding(.horizontal, 12)
                    .padding(.bottom, 24)
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("Gallery")
        .navigationBarTitleDisplayMode(.inline)
        // No custom back button — the system-provided one (native glass
        // pill under the current iOS look) already matches the mockup.
        .fullScreenCover(isPresented: $showAddPhotos) {
            // Reuses the real photo-add flow from main (Views/Photos) —
            // its own gallery/composer/camera UI, not a mock. Scoped to
            // the whole place rather than one facility since this Gallery
            // isn't facility-specific.
            FacilityPhotosView(facilityName: MockData.placeName, onBack: { showAddPhotos = false })
        }
    }

    private var addPhotosButton: some View {
        Button {
            showAddPhotos = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Add Photos")
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    /// Simple, robust layout: full-width hero photo, then the remainder in
    /// a plain 2-column grid of equal square tiles.
    private var photoGrid: some View {
        let photos = filteredPhotos
        let hero = photos.first
        let rest = Array(photos.dropFirst())
        let columns = [GridItem(.flexible(), spacing: 6), GridItem(.flexible(), spacing: 6)]

        return VStack(spacing: 6) {
            if let hero {
                MockPhotoTile(photo: hero)
                    .aspectRatio(4 / 3, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                Text("No photos yet for this filter.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 40)
            }

            if !rest.isEmpty {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(rest) { photo in
                        MockPhotoTile(photo: photo)
                            .aspectRatio(1, contentMode: .fill)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MockGalleryView()
    }
}
