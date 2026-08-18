import PhotosUI
import SwiftUI

/// Photos tab of a facility's detail screen — the whole add-photos flow lives
/// here (Figma nodes 518:16038 default, 572:6900 with the source menu open,
/// 572:7071 after a successful submit).
///
/// The flow: **Add Photos** opens a menu (Choose Existing / Take New Photo);
/// whichever source the user picks hands its images to `AddPhotosView`, and
/// submitting there drops them into the gallery behind a green toast.
struct FacilityPhotosView: View {
    /// Names the facility this gallery belongs to ("Entrances" in the mockup).
    let facilityName: String
    var onBack: () -> Void

    @StateObject private var store: FacilityPhotoStore

    /// Which page of the flow is on screen. The composer is swapped in here
    /// rather than presented as a sheet over the gallery: it is pushed straight
    /// after the photo picker dismisses, and stacking one presentation on
    /// another mid-dismissal leaves the composer laid out under the status bar.
    private enum Screen {
        case gallery
        case composer
    }

    @State private var screen: Screen = .gallery
    @State private var selectedTab: FacilityDetailTab = .photos
    @State private var isLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var stagedPhotos: [FacilityPhoto] = []
    @State private var showsSuccessToast = false
    @State private var toastDismissTask: Task<Void, Never>?

    init(
        facilityName: String,
        photos: [FacilityPhoto] = FacilityPhoto.samples,
        onBack: @escaping () -> Void = {}
    ) {
        self.facilityName = facilityName
        self.onBack = onBack
        _store = StateObject(wrappedValue: FacilityPhotoStore(photos: photos))
    }

    var body: some View {
        ZStack {
            switch screen {
            case .gallery:
                gallery
                    .transition(.move(edge: .leading).combined(with: .opacity))
            case .composer:
                AddPhotosView(
                    initialPhotos: stagedPhotos,
                    onSubmit: { submitted in
                        store.add(submitted)
                        goToGallery()
                        showToast()
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
    }

    private var gallery: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                PhotoFlowHeader(title: facilityName, onBack: onBack)

                // The tab switcher is pinned: only the Add Photos pill and the
                // gallery below it scroll, so changing tabs is always reachable.
                FacilitySegmentedControl(selection: $selectedTab)
                    .padding(.horizontal, PhotoMetrics.gutter)
                    .background(Color(.systemBackground))
                    .zIndex(1)

                ScrollView {
                    tabContent(contentWidth: proxy.size.width)
                }
            }
            // The toast covers the top of the content block, not the toolbar
            // (top-[114px] against content at top-[116px]).
            .overlay(alignment: .top) {
                if showsSuccessToast {
                    PhotoSuccessToast(message: "Your photos successfully added!") {
                        hideToast()
                    }
                    .padding(.horizontal, PhotoMetrics.composerHorizontalPadding)
                    .offset(y: PhotoMetrics.toolbarHeight + PhotoMetrics.toastTopOffset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
    }

    // MARK: Tabs

    @ViewBuilder
    private func tabContent(contentWidth: CGFloat) -> some View {
        switch selectedTab {
        case .photos:
            photosTab(contentWidth: contentWidth)
        case .overview, .reviews:
            // TODO(design): only the Photos tab has been designed so far —
            // these two get a plain holding state rather than an invented one.
            unavailableTab
        }
    }

    private func photosTab(contentWidth: CGFloat) -> some View {
        VStack(spacing: 0) {
            addPhotosButton
                .padding(.horizontal, PhotoMetrics.gutter)
                .padding(.top, PhotoMetrics.addPhotosTopPadding)

            PhotoMosaicGrid(
                photos: store.photos,
                width: max(contentWidth - PhotoMetrics.gutter * 2, 0)
            )
            .padding(PhotoMetrics.gutter)
        }
    }

    private var unavailableTab: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.dashed")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("\(selectedTab.title) isn't available yet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    // MARK: Add Photos

    private var addPhotosButton: some View {
        Menu {
            Button {
                isLibraryPresented = true
            } label: {
                Label("Choose Existing", systemImage: "photo.on.rectangle")
            }

            Button {
                isCameraPresented = true
            } label: {
                Label("Take New Photo", systemImage: "camera")
            }
            // Greyed out in the Simulator and on camera-less devices, which is
            // the Disabled state the mockup shows for this item.
            .disabled(!CameraPicker.isAvailable)
        } label: {
            HStack(spacing: PhotoMetrics.addPhotosSpacing) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 20))
                Text("Add Photos")
                    .font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .semibold))
            }
            .foregroundStyle(PhotoPalette.brandBlue)
            .frame(maxWidth: .infinity)
            .frame(height: PhotoMetrics.addPhotosHeight)
            .background(Capsule().fill(PhotoPalette.background1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add photos")
    }

    // MARK: Staging

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
    }

    private func goToGallery() {
        stagedPhotos = []
        withAnimation(.snappy(duration: 0.3)) { screen = .gallery }
    }

    // MARK: Toast

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
