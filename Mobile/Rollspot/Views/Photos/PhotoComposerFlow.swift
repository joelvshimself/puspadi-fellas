import PhotosUI
import SwiftUI

/// The one "add photos" flow, shared by every Add Photos button (Figma
/// "Photos - Adding Photo" → "Photos - Confirm photos"): a source dialog,
/// the library/camera pickers, the AddPhotosView composer, and the Storage
/// upload with its progress and error surfaces.
///
/// Place Details, Gallery and the facility gallery each grew their own copy of
/// these five steps, and they drifted — one showed success for failed uploads,
/// another reset its own state right after a successful one. Attaching this
/// modifier is now the whole integration: the call site owns only the button
/// and what to do once the backend has accepted the photos.
/// Where the next photos come from — set by the Add Photos `Menu` at the call
/// site ("Choose Existing" / "Take New Photo", as the design draws it).
enum PhotoComposerSource: String, Identifiable {
    case library, camera
    var id: String { rawValue }
}

struct PhotoComposerFlow: ViewModifier {
    /// Set from the Add Photos menu; the flow drives everything after.
    @Binding var source: PhotoComposerSource?
    let place: Place
    let facility: FacilityKind
    /// Runs after the backend accepted the upload, with the submitted photos —
    /// refresh stores / show a toast here. Never called on failure.
    let onUploaded: ([FacilityPhoto]) -> Void

    /// Camera and composer share ONE cover rather than owning one each.
    /// Place Details already stacks four `fullScreenCover`s of its own; adding
    /// two more put seven presentations on a single view chain, and SwiftUI
    /// quietly drops one when several compete — which is how tapping Add
    /// Photos ended up leaving you on the existing photo grid with nothing
    /// presented. It also makes camera → composer a content swap inside the
    /// same cover instead of a dismiss/re-present race.
    private enum Stage: String, Identifiable {
        case camera, composer
        var id: String { rawValue }
    }

    @State private var stage: Stage?
    @State private var isLibraryPresented = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var stagedPhotos: [FacilityPhoto] = []
    /// New value per staging — keys the composer's identity so every
    /// presentation starts from a fresh tray instead of a previous run's state.
    @State private var stagingToken = UUID()
    @State private var isUploading = false
    @State private var uploadError: String?

    func body(content: Content) -> some View {
        content
            .onChange(of: source) { _, requested in
                guard let requested else { return }
                source = nil
                switch requested {
                case .library: isLibraryPresented = true
                case .camera: stage = .camera
                }
            }
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
            .fullScreenCover(item: $stage) { current in
                switch current {
                case .camera:
                    CameraPicker(
                        // Same cover, so this is a content swap — no dismissal
                        // to wait out and nothing to race.
                        onCapture: { image in stageFromCamera([FacilityPhoto(image: image)]) },
                        onCancel: { stage = nil }
                    )
                    .ignoresSafeArea()
                case .composer:
                    composer
                }
            }
    }

    /// The alert lives on the composer, not on `content` — an alert attached
    /// beneath a full-screen cover never surfaces while the cover is up, which
    /// is exactly when the upload fails.
    private var composer: some View {
        AddPhotosView(
            initialPhotos: stagedPhotos,
            onSubmit: { submitted in Task { await upload(submitted) } },
            onBack: { stage = nil }
        )
        .id(stagingToken)
        .overlay {
            if isUploading {
                ProgressView("Uploading…".localized)
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .alert(
            "Couldn't add your photos".localized,
            isPresented: Binding(get: { uploadError != nil }, set: { if !$0 { uploadError = nil } }),
            presenting: uploadError
        ) { _ in
            Button("OK") { uploadError = nil }
        } message: { message in
            Text(message)
        }
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
        stageFromLibrary(picked)
    }

    private func stageFromCamera(_ photos: [FacilityPhoto]) {
        guard !photos.isEmpty else { return }
        stagedPhotos = photos
        stagingToken = UUID()
        stage = .composer
    }

    /// The library picker is its own presentation, so this one genuinely has a
    /// dismissal to wait out. The delay is no longer load-bearing for layout —
    /// AddPhotosView falls back to the window's safe-area insets if the cover
    /// comes up without any — it only avoids presenting into a dismissal.
    private func stageFromLibrary(_ photos: [FacilityPhoto]) {
        guard !photos.isEmpty else { return }
        stagedPhotos = photos
        stagingToken = UUID()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(400))
            stage = .composer
        }
    }

    @MainActor
    private func upload(_ submitted: [FacilityPhoto]) async {
        guard !isUploading else { return }
        isUploading = true
        defer { isUploading = false }
        do {
            try await ReviewService.shared.submitGalleryPhotos(
                place: place,
                facility: facility,
                localPhotos: submitted
            )
            stage = nil
            onUploaded(submitted)
        } catch {
            // The composer stays up with the photos still staged, so a retry
            // is one tap — never report success for an upload that failed.
            print("[PhotoComposerFlow] Photo upload FAILED: \(error)")
            uploadError = Self.errorMessage(for: error)
        }
    }

    /// Storage rejects an unauthenticated upload with a row-level-security
    /// error, which is true but unreadable — say the thing the user can act on.
    static func errorMessage(for error: Error) -> String {
        let text = "\(error)".lowercased()
        if text.contains("row-level security")
            || text.contains("sign in")
            || text.contains("unauthorized")
            || text.contains("401")
            || text.contains("403") {
            return "You need to be signed in to add photos. Sign in and try again.".localized
        }
        return "Your photos couldn't be uploaded. Check your connection and try again.".localized
    }
}

extension View {
    /// Attach the shared add-photos flow. Set `source` from the Add Photos
    /// menu; `onUploaded` fires only after a successful upload.
    func photoComposerFlow(
        source: Binding<PhotoComposerSource?>,
        place: Place,
        facility: FacilityKind,
        onUploaded: @escaping ([FacilityPhoto]) -> Void
    ) -> some View {
        modifier(PhotoComposerFlow(
            source: source,
            place: place,
            facility: facility,
            onUploaded: onUploaded
        ))
    }
}
