import PhotosUI
import SwiftUI

/// Single-select follow-up question — entrance's Ramp/Handrail screens
/// (shown only when that chip was picked) and every elevator question.
/// Single-select rows (not the usual multi-select chips), and picking
/// `photoRevealOption` ("Not sure") reveals an inline Add Photos box, same
/// visual as ContributePhotosNotesStepView's but scoped to this question.
struct ContributeAccessFollowupStepView: View {
    let navTitle: String
    let illustrationAssetName: String
    let eyebrow: String
    let questionTitle: String
    let progress: (current: Int, total: Int)
    let options: [String]
    /// Which option (last one, "Not sure") reveals the Add Photos box.
    let photoRevealOption: String
    @Binding var selection: String?
    @Binding var note: ReviewNoteDraft
    var stepNumber: Int = 1
    var subStepProgress: CGFloat = 0.35
    let onBack: () -> Void
    let onContinue: () -> Void

    private static let topSectionID = "topSection"
    private static let photosSectionID = "photosSection"
    private static let bottomSpacerID = "bottomSpacer"

    @State private var showPhotosSection = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var scrollTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)
            }
            .background(Color(.systemBackground))
            .zIndex(1)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Image(illustrationAssetName)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity)
                            .scaleEffect(1.05)
                            .frame(height: 180)
                            .id(Self.topSectionID)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(eyebrow.localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(questionTitle.localized)
                                .font(.title2.bold())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            ForEach(options, id: \.self) { option in
                                optionRow(option)
                            }
                        }

                        if showPhotosSection {
                            addPhotosBox
                                .id(Self.photosSectionID)
                                .transition(.opacity)

                            Spacer()
                                .frame(height: 40)
                                .id(Self.bottomSpacerID)
                        }
                    }
                    .padding(20)
                }
                .onAppear {
                    showPhotosSection = (selection == photoRevealOption)
                }
                .onChange(of: selection) { oldVal, newVal in
                    scrollTask?.cancel()
                    scrollTask = Task { @MainActor in
                        let isShortForm = options.count <= 3

                        if newVal == photoRevealOption {
                            showPhotosSection = true
                            try? await Task.sleep(nanoseconds: 30_000_000)
                            guard !Task.isCancelled else { return }
                            withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
                                proxy.scrollTo(Self.bottomSpacerID, anchor: .bottom)
                            }
                        } else if oldVal == photoRevealOption {
                            if isShortForm {
                                withAnimation(.snappy(duration: 0.32)) {
                                    showPhotosSection = false
                                }
                            } else {
                                withAnimation(.easeInOut(duration: 0.35)) {
                                    proxy.scrollTo(Self.topSectionID, anchor: .top)
                                }
                                try? await Task.sleep(nanoseconds: 360_000_000)
                                guard !Task.isCancelled else { return }
                                if selection != photoRevealOption {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showPhotosSection = false
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ContributeContinueButton(isEnabled: selection != nil, action: onContinue)
        }
        .background(Color(.systemBackground))
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

    @State private var showPhotoOptions = false
    @State private var selectedPhotoForCaption: ReviewPhotoDraft? = nil

    private func optionRow(_ option: String) -> some View {
        let isSelected = selection == option
        return Button {
            selection = option
        } label: {
            Text(option.localized)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }

    private var addPhotosBox: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("(Optional)".localized)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)

            if note.photos.isEmpty {
                addPhotoButtonTile(isWide: true)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        if note.canAddMorePhotos {
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
        .disabled(!note.canAddMorePhotos)
        .opacity(note.canAddMorePhotos ? 1 : 0.4)
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
    ContributeAccessFollowupStepView(
        navTitle: "Entrances",
        illustrationAssetName: "Lobby Asset",
        eyebrow: "Ramps",
        questionTitle: "Could you push your wheelchair up the ramp without help?",
        progress: (2, 6),
        options: ["Yes", "With a push", "Too steep", "Not sure"],
        photoRevealOption: "Not sure",
        selection: .constant(nil),
        note: .constant(ReviewNoteDraft()),
        onBack: {},
        onContinue: {}
    )
}
