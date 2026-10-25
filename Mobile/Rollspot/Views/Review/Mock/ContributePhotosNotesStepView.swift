import PhotosUI
import SwiftUI

/// "Anything else you want to share?" (Figma "Question 3 - Filled"): optional notes, then the
/// section's photos with Add Photos (Choose Existing / Take New Photo), tap-to-caption and remove.
struct ContributePhotosNotesStepView: View {
    let facilityName: String
    let navTitle: String
    let progress: (current: Int, total: Int)
    /// The notes text (and, without [photoNote], the photos too).
    @Binding var note: ReviewNoteDraft
    /// Where the photos live when they belong to the section rather than the note
    /// (design: the photos taken at the start of the section show here).
    var photoNote: Binding<ReviewNoteDraft>? = nil
    /// When set, caps how many more photos can be added (Final Review uses
    /// toilet's remaining slots while still displaying all prior photos).
    var remainingPhotoSlots: Int? = nil
    var showsPhotos: Bool = true
    var continueTitle: String = "Continue"
    var isLastStep: Bool = false
    var isSubmitting: Bool = false
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var showPhotoOptions = false
    @State private var selectedPhotoForCaption: ReviewPhotoDraft? = nil
    @FocusState private var notesFocused: Bool

    private static let tileSize: CGFloat = 142

    private var photos: Binding<ReviewNoteDraft> { photoNote ?? $note }

    private var effectiveCanAddMorePhotos: Bool {
        if let remainingPhotoSlots {
            return remainingPhotoSlots > 0
        }
        return photos.wrappedValue.canAddMorePhotos
    }

    private var effectiveRemainingPhotoSlots: Int {
        if let remainingPhotoSlots {
            return max(remainingPhotoSlots, 0)
        }
        return max(ReviewNoteDraft.maxPhotos - photos.wrappedValue.photos.count, 0)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                ContributeStepProgressBar(currentStep: 4)
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    notesSection
                    if showsPhotos {
                        photosSection
                            .padding(.top, 34)
                    }
                }
                .padding(.horizontal, 21)
                .padding(.top, 62)
                .padding(.bottom, 8)
            }
            .scrollDismissesKeyboard(.interactively)

            ContributeContinueButton(
                title: continueTitle,
                isLoading: isSubmitting,
                isEnabled: !isSubmitting,
                action: onContinue
            )
        }
        .background(Color(.systemBackground))
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
                    photos.wrappedValue.updatePhotoCaption(id: photo.id, caption: newCaption)
                },
                onDismiss: {
                    selectedPhotoForCaption = nil
                }
            )
        }
    }

    private func sectionTitle(_ title: String, inline: Bool) -> some View {
        let optional = Text("(Optional)".localized)
            .font(.system(size: 14))
            .foregroundStyle(ContributePalette.optionalText)
        return Group {
            if inline {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title.localized)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ContributePalette.text)
                    optional
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(title.localized)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(ContributePalette.text)
                    optional
                }
            }
        }
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Anything else you want to share?", inline: false)

            ZStack(alignment: .topLeading) {
                if note.text.isEmpty {
                    Text("Tell us more about your experience ...".localized)
                        .font(.system(size: 15))
                        .foregroundStyle(ContributePalette.placeholder)
                        .padding(.horizontal, 15)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
                TextField("", text: $note.text, axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundStyle(ContributePalette.text)
                    .lineLimit(1...7)
                    .focused($notesFocused)
                    .padding(.horizontal, 15)
                    .padding(.vertical, 16)
            }
            .frame(maxWidth: .infinity, minHeight: 144, alignment: .topLeading)
            .background(ContributePalette.fill, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(ContributePalette.blue.opacity(notesFocused ? 0.5 : 0), lineWidth: 2)
            }
            .contentShape(Rectangle())
            .onTapGesture { notesFocused = true }
            .animation(.easeOut(duration: 0.15), value: notesFocused)
        }
    }

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle("Photos", inline: true)

            if photos.wrappedValue.photos.isEmpty {
                addPhotoTile(isWide: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if effectiveCanAddMorePhotos {
                            addPhotoTile(isWide: false)
                        }
                        ForEach(photos.wrappedValue.photos) { photo in
                            photoThumbnail(photo)
                                .transition(.scale(scale: 0.9).combined(with: .opacity))
                        }
                    }
                    .padding(.horizontal, 21)
                }
                // The strip runs to the screen edges, as in the design.
                .padding(.horizontal, -21)
            }
        }
    }

    private func addPhotoTile(isWide: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return Button {
            notesFocused = false
            showPhotoOptions.toggle()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(ContributePalette.blue)
                Text("Add Photos".localized)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(ContributePalette.blue)
                    .lineLimit(1)
                    .fixedSize()
            }
            .frame(width: isWide ? nil : Self.tileSize, height: Self.tileSize)
            .frame(maxWidth: isWide ? .infinity : nil)
            .background(ContributePalette.fill, in: shape)
            .overlay {
                shape.strokeBorder(ContributePalette.dash, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            }
            .contentShape(shape)
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(!effectiveCanAddMorePhotos)
        .opacity(effectiveCanAddMorePhotos ? 1 : 0.4)
        .popover(isPresented: $showPhotoOptions, attachmentAnchor: .point(.center), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 16) {
                photoOption("Choose Existing", systemImage: "photo.on.rectangle") {
                    showPhotoOptions = false
                    showPhotosPicker = true
                }
                if CameraPicker.isAvailable {
                    photoOption("Take New Photo", systemImage: "camera") {
                        showPhotoOptions = false
                        showCamera = true
                    }
                }
            }
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func photoOption(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(title.localized)
                    .font(.system(size: 15))
            }
            .foregroundStyle(ContributePalette.text)
        }
        .buttonStyle(.plain)
    }

    private func photoThumbnail(_ photo: ReviewPhotoDraft) -> some View {
        let hasCaption = !photo.caption.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        return Button {
            selectedPhotoForCaption = photo
        } label: {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: Self.tileSize, height: Self.tileSize)
                .clipShape(shape)
                .overlay(alignment: .bottomLeading) {
                    if hasCaption {
                        // "Added caption shows caption icon".
                        Image(systemName: "text.bubble.fill")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 20, height: 20)
                            .background(Color.black.opacity(0.75), in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 1.5))
                            .padding(8)
                    }
                }
        }
        .buttonStyle(PressableButtonStyle())
        .overlay(alignment: .topTrailing) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    photos.wrappedValue.removePhoto(id: photo.id)
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 18, height: 18)
                    .background(Color.white, in: Circle())
                    .shadow(color: .black.opacity(0.15), radius: 2, y: 1)
                    // Bigger hit area than the 18pt circle.
                    .frame(width: 36, height: 36)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove photo".localized)
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
        guard effectiveCanAddMorePhotos else { return }

        withAnimation(.easeOut(duration: 0.2)) {
            if remainingPhotoSlots != nil {
                guard let encoded = PhotoEncoder.encode(image) else { return }
                photos.wrappedValue.photos.append(ReviewPhotoDraft(image: encoded.image, jpegData: encoded.jpeg))
            } else {
                photos.wrappedValue.addPhoto(from: image)
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
