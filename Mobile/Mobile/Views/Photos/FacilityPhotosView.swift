import PhotosUI
import SwiftUI

/// Photos tab of a facility's detail screen — add photos via library or camera.
struct FacilityPhotosView: View {
    let facilityName: String
    var place: Place?
    var facilityKind: FacilityKind?
    var onBack: () -> Void
    var showsChrome: Bool
    var onComposingChanged: ((Bool) -> Void)?
    var onPhotosChanged: (() -> Void)?

    @StateObject private var store: FacilityPhotoStore

    private enum Screen { case gallery, composer }

    @State private var screen: Screen = .gallery
    @State private var internalTab: FacilityDetailTab = .photos
    private var externalTab: Binding<FacilityDetailTab>?
    @State private var isLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var stagedPhotos: [FacilityPhoto] = []
    @State private var lightbox: LightboxSelection?
    @State private var showsSuccessToast = false
    @State private var toastDismissTask: Task<Void, Never>?
    @State private var isUploading = false

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    private var selectedTab: Binding<FacilityDetailTab> {
        externalTab ?? $internalTab
    }

    init(
        facilityName: String,
        photos: [FacilityPhoto] = [],
        place: Place? = nil,
        facilityKind: FacilityKind? = nil,
        onBack: @escaping () -> Void = {}
    ) {
        self.init(
            facilityName: facilityName,
            photos: photos,
            place: place,
            facilityKind: facilityKind,
            selectedTab: nil,
            showsChrome: true,
            onBack: onBack,
            onComposingChanged: nil,
            onPhotosChanged: nil
        )
    }

    init(
        facilityName: String,
        photos: [FacilityPhoto] = [],
        place: Place? = nil,
        facilityKind: FacilityKind? = nil,
        selectedTab: Binding<FacilityDetailTab>,
        showsChrome: Bool,
        onBack: @escaping () -> Void = {},
        onComposingChanged: ((Bool) -> Void)? = nil,
        onPhotosChanged: (() -> Void)? = nil
    ) {
        self.init(
            facilityName: facilityName,
            photos: photos,
            place: place,
            facilityKind: facilityKind,
            selectedTab: Optional(selectedTab),
            showsChrome: showsChrome,
            onBack: onBack,
            onComposingChanged: onComposingChanged,
            onPhotosChanged: onPhotosChanged
        )
    }

    private init(
        facilityName: String,
        photos: [FacilityPhoto],
        place: Place?,
        facilityKind: FacilityKind?,
        selectedTab: Binding<FacilityDetailTab>?,
        showsChrome: Bool,
        onBack: @escaping () -> Void,
        onComposingChanged: ((Bool) -> Void)?,
        onPhotosChanged: (() -> Void)?
    ) {
        self.facilityName = facilityName
        self.place = place
        self.facilityKind = facilityKind
        self.onBack = onBack
        self.showsChrome = showsChrome
        self.onComposingChanged = onComposingChanged
        self.onPhotosChanged = onPhotosChanged
        self.externalTab = selectedTab
        _store = StateObject(wrappedValue: FacilityPhotoStore(photos: photos))
    }

    var body: some View {
        ZStack {
            switch screen {
            case .gallery:
                gallery.transition(.move(edge: .leading).combined(with: .opacity))
            case .composer:
                AddPhotosView(
                    initialPhotos: stagedPhotos,
                    onSubmit: { submitted in
                        Task { await submitPhotos(submitted) }
                    },
                    onBack: { goToGallery() }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .background(Color(.systemBackground))
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
        .onDisappear { toastDismissTask?.cancel() }
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
    }

    private var gallery: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                if showsChrome {
                    PhotoFlowHeader(title: facilityName, onBack: onBack)
                    FacilitySegmentedControl(selection: selectedTab)
                        .padding(.horizontal, PhotoMetrics.gutter)
                        .background(Color(.systemBackground))
                        .zIndex(1)
                }

                ScrollView {
                    if showsChrome {
                        tabContent(contentWidth: proxy.size.width)
                    } else {
                        photosTab(contentWidth: proxy.size.width)
                    }
                }
            }
            .overlay(alignment: .top) {
                if showsSuccessToast {
                    PhotoSuccessToast(message: "Your photos successfully added!") { hideToast() }
                        .padding(.horizontal, PhotoMetrics.composerHorizontalPadding)
                        .offset(y: (showsChrome ? PhotoMetrics.toolbarHeight : 0) + PhotoMetrics.toastTopOffset)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    @ViewBuilder
    private func tabContent(contentWidth: CGFloat) -> some View {
        switch selectedTab.wrappedValue {
        case .photos: photosTab(contentWidth: contentWidth)
        case .overview, .reviews: unavailableTab
        }
    }

    private func photosTab(contentWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            addPhotosButton
                .padding(.horizontal, PhotoMetrics.gutter)
                .padding(.top, PhotoMetrics.addPhotosTopPadding)

            if store.photos.isEmpty {
                Text("No photos yet")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                PhotoMosaicGrid(
                    photos: store.photos,
                    width: max(contentWidth - PhotoMetrics.gutter * 2, 0),
                    onSelect: { photo in openLightbox(for: photo) }
                )
                .padding(PhotoMetrics.gutter)
            }
        }
    }

    private func openLightbox(for photo: FacilityPhoto) {
        let siblings: [FacilityPhoto]
        if let reviewId = photo.reviewId {
            siblings = store.photos.filter { $0.reviewId == reviewId }
        } else {
            siblings = [photo]
        }
        lightbox = LightboxSelection(photos: siblings, initialID: photo.id)
    }

    private var unavailableTab: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed").font(.largeTitle).foregroundStyle(.tertiary)
            Text("\(selectedTab.wrappedValue.title) isn't available yet.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity).padding(.top, 80)
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
            HStack(spacing: PhotoMetrics.addPhotosSpacing) {
                Image(systemName: "photo.badge.plus.fill").font(.system(size: 20))
                Text("Add Photos").font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .semibold))
            }
            .foregroundStyle(PhotoPalette.brandBlue)
            .frame(maxWidth: .infinity)
            .frame(height: PhotoMetrics.addPhotosHeight)
            .background(Capsule().fill(PhotoPalette.background1))
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
        withAnimation(.snappy(duration: 0.3)) { screen = .composer }
        onComposingChanged?(true)
    }

    private func goToGallery() {
        stagedPhotos = []
        withAnimation(.snappy(duration: 0.3)) { screen = .gallery }
        onComposingChanged?(false)
    }

    @MainActor
    private func submitPhotos(_ submitted: [FacilityPhoto]) async {
        guard let place, let facilityKind else {
            store.add(submitted)
            goToGallery()
            showToast()
            return
        }
        isUploading = true
        defer { isUploading = false }
        do {
            try await ReviewService.shared.submitGalleryPhotos(
                place: place,
                facility: facilityKind,
                localPhotos: submitted
            )
            goToGallery()
            showToast()
            onPhotosChanged?()
        } catch {
            store.add(submitted)
            goToGallery()
            showToast()
        }
    }

    private func showToast() {
        toastDismissTask?.cancel()
        withAnimation(.snappy) { showsSuccessToast = true }
        toastDismissTask = Task {
            try? await Task.sleep(for: PhotoMetrics.toastDuration)
            guard !Task.isCancelled else { return }
            hideToast()
        }
    }

    private func hideToast() {
        toastDismissTask?.cancel()
        withAnimation(.snappy) { showsSuccessToast = false }
    }
}

#Preview {
    FacilityPhotosView(facilityName: "Entrances")
}
