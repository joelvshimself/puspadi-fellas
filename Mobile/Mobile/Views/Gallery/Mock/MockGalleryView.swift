import PhotosUI
import SwiftUI

/// Gallery screen — live backend photos with inline add (library / camera).
struct MockGalleryView: View {
    var streetImageURL: URL? = nil
    var reviewPhotos: [ReviewPhoto] = []
    var place: Place

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

    private enum Screen { case gallery, composer }

    @State private var selectedFilter: Filter = .all
    @State private var screen: Screen = .gallery
    @State private var isLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var stagedPhotos: [FacilityPhoto] = []
    @State private var lightbox: LightboxSelection?
    @State private var localPhotos: [FacilityPhoto] = []
    @State private var isUploading = false
    @State private var reloadToken = UUID()

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    private var galleryFacilityPhotos: [FacilityPhoto] {
        var photos: [FacilityPhoto] = localPhotos

        if selectedFilter == .all, let streetImageURL {
            photos.append(FacilityPhoto(source: .remote(streetImageURL)))
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
        ZStack {
            switch screen {
            case .gallery:
                galleryContent
            case .composer:
                AddPhotosView(
                    initialPhotos: stagedPhotos,
                    onSubmit: { submitted in Task { await submitPhotos(submitted) } },
                    onBack: { withAnimation { screen = .gallery } }
                )
            }
        }
        .background(Color(.systemBackground))
        .navigationTitle("GALLERY".localized.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .photosPicker(
            isPresented: $isLibraryPresented,
            selection: $librarySelection,
            maxSelectionCount: AddPhotosView.maxPhotos,
            matching: .images
        )
        .onChange(of: librarySelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await stagePickedPhotos(newItems)
                librarySelection = []
            }
        }
        .fullScreenCover(isPresented: $isCameraPresented) {
            CameraPicker(
                onCapture: { image in
                    isCameraPresented = false
                    stage([FacilityPhoto(image: image)])
                },
                onCancel: { isCameraPresented = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $lightbox) { selection in
            FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
        }
        .overlay {
            if isUploading {
                ProgressView("Uploading…")
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .id(reloadToken)
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
            Button { isLibraryPresented = true } label: {
                Label("Choose Existing", systemImage: "photo.on.rectangle")
            }
            Button { isCameraPresented = true } label: {
                Label("Take New Photo", systemImage: "camera")
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

    @MainActor
    private func stagePickedPhotos(_ items: [PhotosPickerItem]) async {
        var picked: [FacilityPhoto] = []
        for item in items where picked.count < AddPhotosView.maxPhotos {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                picked.append(FacilityPhoto(image: image))
            }
        }
        stage(picked)
    }

    private func stage(_ photos: [FacilityPhoto]) {
        guard !photos.isEmpty else { return }
        stagedPhotos = photos
        withAnimation { screen = .composer }
    }

    @MainActor
    private func submitPhotos(_ submitted: [FacilityPhoto]) async {
        let kind = selectedFilter.facilityKind ?? .entrance
        isUploading = true
        defer { isUploading = false }
        do {
            try await ReviewService.shared.submitGalleryPhotos(
                place: place,
                facility: kind,
                localPhotos: submitted
            )
            localPhotos.insert(contentsOf: submitted, at: 0)
            withAnimation { screen = .gallery }
            reloadToken = UUID()
        } catch {
            localPhotos.insert(contentsOf: submitted, at: 0)
            withAnimation { screen = .gallery }
        }
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
