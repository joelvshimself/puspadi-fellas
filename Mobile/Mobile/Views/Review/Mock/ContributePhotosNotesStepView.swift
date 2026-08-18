import PhotosUI
import SwiftUI

/// Photos + Notes step — matches the mockup's dashed "Add Photos" box with
/// a Choose-Existing/Take-New-Photo action sheet, thumbnail strip, and a
/// Notes textarea. Fresh UI (not a reuse of ReviewAddNoteStepView, per
/// explicit choice), but binds to the real `ReviewNoteDraft` struct so it
/// plugs straight into `ReviewDraft` with no conversion.
struct ContributePhotosNotesStepView: View {
    let facilityName: String
    let navTitle: String
    let progress: (current: Int, total: Int)
    @Binding var note: ReviewNoteDraft
    var isLastStep: Bool = false
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showSourceDialog = false
    @State private var showPhotosPicker = false
    @State private var showCamera = false

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: navTitle, onBack: onBack)
            ReviewProgressBar(currentIndex: progress.current, totalSteps: progress.total)
                .padding(.horizontal, PhotoMetrics.toolbarHorizontalPadding)
                .padding(.top, 4)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    photosSection
                    notesSection
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)

            // Always enabled — explicit tap on this button submits/continues
            ContributeContinueButton(
                title: isLastStep ? "Submit Review" : "Continue",
                isEnabled: true,
                action: onContinue
            )
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .confirmationDialog("Add Photo".localized, isPresented: $showSourceDialog, titleVisibility: .visible) {
            Button("Choose Existing".localized) { showPhotosPicker = true }
            if CameraPicker.isAvailable {
                Button("Take New Photo".localized) { showCamera = true }
            }
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoPickerItems,
            maxSelectionCount: ReviewNoteDraft.maxPhotos - note.photos.count,
            matching: .images
        )
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await loadPhotos(from: newItems)
                photoPickerItems = []
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraPicker(
                onCapture: { image in
                    note.addPhoto(from: image)
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("\("Photos of".localized) \(facilityName.localized)")
                    .font(.system(size: 18, weight: .bold))
                Text("(Optional)".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if note.canAddMorePhotos {
                addPhotosBox
            }

            if !note.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(note.photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                }
            }
        }
    }

    private var addPhotosBox: some View {
        Button {
            if note.canAddMorePhotos {
                showSourceDialog = true
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                Text(note.photos.isEmpty ? "Add Photos".localized : "Add More Photos".localized)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Color.accentColor.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [6]))
            }
        }
        .buttonStyle(.plain)
        .disabled(!note.canAddMorePhotos)
        .opacity(note.canAddMorePhotos ? 1 : 0.4)
    }

    private func photoThumbnail(_ photo: ReviewPhotoDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button {
                note.removePhoto(id: photo.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.plain)
            .padding(4)
            .accessibilityLabel("Remove photo")
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("Notes".localized)
                    .font(.system(size: 18, weight: .bold))
                Text("(Optional)".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            TextField("Tell us more about your experience …".localized, text: $note.text, axis: .vertical)
                .font(.subheadline)
                .lineLimit(4...8)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
        }
    }

    @MainActor
    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            guard note.canAddMorePhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                note.addPhoto(from: image)
            }
        }
    }
}

#Preview {
    ContributePhotosNotesStepView(
        facilityName: "Entrance",
        navTitle: "Entrances",
        progress: (3, 6),
        note: .constant(ReviewNoteDraft()),
        onBack: {},
        onContinue: {}
    )
}
