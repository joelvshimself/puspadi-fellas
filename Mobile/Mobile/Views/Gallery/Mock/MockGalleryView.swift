import PhotosUI
import SwiftUI

/// Gallery screen — live backend photos with inline add (library / camera).
struct MockGalleryView: View {
    var streetImageURL: URL? = nil
    /// Curated photographs of the venue itself. Shown under ALL, ahead of the
    /// street-level capture — they are pictures of the place, not of one
    /// facility, so no facility filter matches them.
    var venuePhotos: [PlacePhoto] = []
    var reviewPhotos: [ReviewPhoto] = []
    var place: Place
    /// Lets the owning screen refetch its stores after an upload, so the new
    /// photos are also there when the user navigates back.
    var onPhotosChanged: (() -> Void)? = nil

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

        var facilityKind: FacilityKind? {
            switch self {
            case .all: nil
            case .entrance: .entrance
            case .elevator: .elevator
            case .toilet: .toilet
            }
        }
    }

    @State private var selectedFilter: Filter = .all
    @State private var photoSource: PhotoComposerSource?
    @State private var lightbox: LightboxSelection?
    /// Uploads from this session, shown ahead of the backend list so they are
    /// visible the moment the composer closes.
    @State private var localPhotos: [FacilityPhoto] = []

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    private var galleryFacilityPhotos: [FacilityPhoto] {
        var photos: [FacilityPhoto] = localPhotos

        if selectedFilter == .all {
            photos.append(contentsOf: venuePhotos.compactMap { photo in
                photo.imageURL.map { FacilityPhoto(source: .remote($0)) }
            })
            if let streetImageURL {
                photos.append(FacilityPhoto(source: .remote(streetImageURL)))
            }
        }

        let matching = reviewPhotos.filter { photo in
            guard let key = selectedFilter.facilityKey else { return true }
            let fac = photo.facility.lowercased()
            return fac.contains(key) ||
                (key == "entrance" && (fac.contains("lobby") || fac.contains("basement")))
        }

        for photo in matching {
            if let url = photo.imageURL {
                photos.append(FacilityPhoto(source: .remote(url)))
            }
        }
        return photos
    }

    var body: some View {
        galleryContent
            .background(Color(.systemBackground))
            .navigationTitle("GALLERY".localized.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .photoComposerFlow(
                source: $photoSource,
                place: place,
                facility: selectedFilter.facilityKind ?? .entrance,
                onUploaded: { submitted in
                    // Show the upload NOW and let the owner refetch. This used
                    // to bump an `.id()` token right after inserting, which
                    // reset the view's state and wiped the photos it had just
                    // added — the upload "vanished" until the next full visit.
                    localPhotos.insert(contentsOf: submitted, at: 0)
                    onPhotosChanged?()
                }
            )
            .fullScreenCover(item: $lightbox) { selection in
                FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
            }
    }

    private var galleryContent: some View {
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
                            onSelect: { photo in
                                lightbox = LightboxSelection(photos: [photo], initialID: photo.id)
                            }
                        )
                        .padding(.horizontal, PhotoMetrics.gutter)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private var addPhotosButton: some View {
        Menu {
            Button { photoSource = .library } label: {
                Label("Choose Existing".localized, systemImage: "photo.on.rectangle")
            }
            Button { photoSource = .camera } label: {
                Label("Take New Photo".localized, systemImage: "camera")
            }
            .disabled(!CameraPicker.isAvailable)
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
        MockGalleryView(
            place: Place.fromSearchResult(
                name: "Park 23 Mall",
                category: "Mall",
                coordinate: .init(latitude: -8.741, longitude: 115.178)
            )
        )
    }
}
