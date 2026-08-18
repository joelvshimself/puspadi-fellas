import SwiftUI

/// "Gallery" screen — renders real backend photos (Mapillary street photo +
/// community review photos from Supabase) using the exact header switcher
/// (`FilterSegmentedControl` with `.nativeToggle` style) and photo mosaic grid
/// (`PhotoMosaicGrid`) from Facility Details.
struct MockGalleryView: View {
    var streetImageURL: URL? = nil
    var reviewPhotos: [ReviewPhoto] = []
    var placeName: String? = nil

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
    @State private var selectedPhoto: FacilityPhoto?

    private var galleryFacilityPhotos: [FacilityPhoto] {
        var photos: [FacilityPhoto] = []

        // 1. Remote photos from backend (street photo + community photos)
        if selectedFilter == .all, let streetImageURL {
            photos.append(FacilityPhoto(source: .remote(streetImageURL)))
        }

        let matchingReviewPhotos = reviewPhotos.filter { photo in
            guard let key = selectedFilter.facilityKey else { return true }
            let fac = photo.facility.lowercased()
            return fac.contains(key) ||
                (key == "entrance" && (fac.contains("lobby") || fac.contains("basement")))
        }

        for photo in matchingReviewPhotos {
            if let url = photo.imageURL {
                photos.append(FacilityPhoto(source: .remote(url)))
            }
        }

        return photos
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                FilterSegmentedControl(
                    options: Filter.allCases,
                    label: { $0.rawValue.localized },
                    selection: $selectedFilter,
                    style: .nativeToggle
                )
                .padding(.horizontal, PhotoMetrics.gutter)
                .padding(.top, 12)

                addPhotosButton
                    .padding(.horizontal, PhotoMetrics.gutter)
                    .padding(.vertical, 16)

                if galleryFacilityPhotos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 40, weight: .light))
                            .foregroundStyle(.secondary)
                        Text("No Photos Available")
                            .font(.headline)
                        Text("Be the first to add photos for this location.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView(showsIndicators: false) {
                        PhotoMosaicGrid(
                            photos: galleryFacilityPhotos,
                            width: max(proxy.size.width - PhotoMetrics.gutter * 2, 0),
                            onSelect: { selectedPhoto = $0 }
                        )
                        .padding(.horizontal, PhotoMetrics.gutter)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("GALLERY".localized.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $showAddPhotos) {
            FacilityPhotosView(facilityName: placeName ?? MockData.placeName, onBack: { showAddPhotos = false })
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FacilityPhotoDetailView(photo: photo)
        }
    }

    private var addPhotosButton: some View {
        Button {
            showAddPhotos = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .medium))
                Text("Add Photos".localized)
                    .font(.system(size: 15, weight: .medium))
            }
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(Color(.secondarySystemBackground), in: Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        MockGalleryView()
    }
}
