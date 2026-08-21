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
struct PhotoComposerFlow: ViewModifier {
    /// Set true from the Add Photos button; the flow drives everything after.
    @Binding var isSourcePresented: Bool
    let place: Place
    let facility: FacilityKind
    /// Runs after the backend accepted the upload, with the submitted photos —
    /// refresh stores / show a toast here. Never called on failure.
    let onUploaded: ([FacilityPhoto]) -> Void

    @State private var isLibraryPresented = false
    @State private var isCameraPresented = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var stagedPhotos: [FacilityPhoto] = []
    @State private var isComposerPresented = false
    /// New value per staging — keys the composer's identity so every
    /// presentation starts from a fresh tray instead of a previous run's state.
    @State private var stagingToken = UUID()
    @State private var isUploading = false
    @State private var uploadError: String?

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Add Photo".localized,
                isPresented: $isSourcePresented,
                titleVisibility: .visible
            ) {
                Button("Choose Existing".localized) { isLibraryPresented = true }
                if CameraPicker.isAvailable {
                    Button("Take New Photo".localized) { isCameraPresented = true }
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
            .fullScreenCover(isPresented: $isComposerPresented) {
                composer
            }
    }

    /// The alert lives on the composer, not on `content` — an alert attached
    /// beneath a full-screen cover never surfaces while the cover is up, which
    /// is exactly when the upload fails.
    private var composer: some View {
        AddPhotosView(
            initialPhotos: stagedPhotos,
            onSubmit: { submitted in Task { await upload(submitted) } },
            onBack: { isComposerPresented = false }
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
        stage(picked)
    }

    private func stage(_ photos: [FacilityPhoto]) {
        guard !photos.isEmpty else { return }
        stagedPhotos = photos
        stagingToken = UUID()
        // Wait out the picker/camera dismissal before presenting. Two
        // presentations racing from the same host is what UIKit half-applies:
        // the composer came up with NO safe-area insets, its back button
        // buried under the status-bar clock and untappable.
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(550))
            isComposerPresented = true
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
            isComposerPresented = false
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
    /// Attach the shared add-photos flow. Toggle `isSourcePresented` from the
    /// Add Photos button; `onUploaded` fires only after a successful upload.
    func photoComposerFlow(
        isSourcePresented: Binding<Bool>,
        place: Place,
        facility: FacilityKind,
        onUploaded: @escaping ([FacilityPhoto]) -> Void
    ) -> some View {
        modifier(PhotoComposerFlow(
            isSourcePresented: isSourcePresented,
            place: place,
            facility: facility,
            onUploaded: onUploaded
        ))
    }
}
