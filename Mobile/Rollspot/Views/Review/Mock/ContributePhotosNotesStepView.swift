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
    /// When set, caps how many more photos can be added (Final Review uses
    /// toilet's remaining slots while still displaying all prior photos).
    var remainingPhotoSlots: Int? = nil
    var isLastStep: Bool = false
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var selectedPhotoForCaption: ReviewPhotoDraft? = nil
    @FocusState private var notesFocused: Bool

    private var effectiveCanAddMorePhotos: Bool {
        if let remainingPhotoSlots {
            return remainingPhotoSlots > 0
        }
        return note.canAddMorePhotos
    }

    private var effectiveRemainingPhotoSlots: Int {
        if let remainingPhotoSlots {
            return max(remainingPhotoSlots, 0)
        }
        return max(ReviewNoteDraft.maxPhotos - note.photos.count, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: 4)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        photosSection
                        notesSection
                            .id("notesSection")
                    }
                    .padding(20)
                    .padding(.bottom, 8)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: notesFocused) { _, focused in
                    if focused {
                        withAnimation {
                            proxy.scrollTo("notesSection", anchor: .bottom)
                        }
                    }
                }
            }

            ContributeContinueButton(
                title: "Submit".localized,
                isEnabled: true,
                action: onContinue
            )
            .padding(.bottom, 8)
        }
        .background(Color(.systemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoPickerItems,
            maxSelectionCount: effectiveRemainingPhotoSlots,
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
                    addPhoto(from: image)
                    showCamera = false
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $selectedPhotoForCaption) { photo in
            PhotoCaptionEditorView(
                photo: photo,
                onSave: { newCaption in
                    note.updatePhotoCaption(id: photo.id, caption: newCaption)
                },
                onDismiss: {
                    selectedPhotoForCaption = nil
                }
            )
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 4) {
                Text("Photos".localized)
                    .font(.system(size: 18, weight: .bold))
                Text("(Optional)".localized)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if note.photos.isEmpty {
                addPhotoButtonTile(isWide: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if effectiveCanAddMorePhotos {
                            addPhotoButtonTile(isWide: false)
                        }

                        ForEach(note.photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                }
            }
        }
    }

    @State private var showPhotoOptions = false

    private func addPhotoButtonTile(isWide: Bool) -> some View {
        Button {
            showPhotoOptions.toggle()
        } label: {
            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                Text("Add Photos".localized)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: isWide ? nil : 120, height: 120)
            .frame(maxWidth: isWide ? .infinity : nil)
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
        .disabled(!effectiveCanAddMorePhotos)
        .opacity(effectiveCanAddMorePhotos ? 1 : 0.4)
        .popover(isPresented: $showPhotoOptions, attachmentAnchor: .point(.center), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    showPhotoOptions = false
                    showPhotosPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(.primary)
                        Text("Choose Existing".localized)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                .buttonStyle(.plain)

                if CameraPicker.isAvailable {
                    Button {
                        showPhotoOptions = false
                        showCamera = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera")
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Take New Photo".localized)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func photoThumbnail(_ photo: ReviewPhotoDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                selectedPhotoForCaption = photo
            } label: {
                ZStack(alignment: .bottomLeading) {
                    Image(uiImage: photo.image)
                        .resizable()
                        .scaledToFill()

                    if !photo.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        PhotoCaptionBadge()
                            .padding(6)
                    }
                }
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.snappy(duration: 0.18)) {
                    note.removePhoto(id: photo.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 24, height: 24)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.18), radius: 3, x: 0, y: 1)
            }
            .buttonStyle(.plain)
            .padding(6)
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
                .focused($notesFocused)
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
            guard effectiveCanAddMorePhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                addPhoto(from: image)
            }
        }
    }

    private func addPhoto(from image: UIImage) {
        guard effectiveCanAddMorePhotos,
              let jpegData = image.jpegData(compressionQuality: ReviewNoteDraft.jpegQuality)
        else { return }

        if remainingPhotoSlots != nil {
            var updated = note
            updated.photos.append(ReviewPhotoDraft(image: image, jpegData: jpegData))
            note = updated
        } else {
            note.addPhoto(from: image)
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
