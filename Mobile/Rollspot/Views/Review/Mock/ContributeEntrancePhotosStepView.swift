import PhotosUI
import SwiftUI

/// Optional entrance photo before the accessible-entrances location picker.
struct ContributeEntrancePhotosStepView: View {
    var navTitle: String = "Entrances"
    var illustrationAssetName: String = "Lobby Asset"
    var stepNumber: Int = 1
    let progress: (current: Int, total: Int)
    var subStepProgress: CGFloat = 0.35
    @Binding var note: ReviewNoteDraft
    let onBack: () -> Void
    let onContinue: () -> Void

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var showPhotosPicker = false
    @State private var showCamera = false
    @State private var showPhotoOptions = false

    var body: some View {
        VStack(spacing: 0) {
                PhotoFlowHeader(title: navTitle.localized, onBack: onBack)
                ContributeStepProgressBar(currentStep: stepNumber, subStepProgress: subStepProgress)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(illustrationAssetName)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Take or upload a photo".localized)
                            .font(.title2.bold())
                        Text("(Optional)".localized)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if note.photos.isEmpty {
                        addPhotoButtonTile(isWide: true)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                if note.canAddMorePhotos {
                                    addPhotoButtonTile(isWide: false)
                                }
                                ForEach(note.photos) { photo in
                                    Image(uiImage: photo.image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                            }
                        }
                    }
                }
                .padding(20)
            }

            ContributeContinueButton(isEnabled: true, action: onContinue)
        }
        .background(Color(.systemBackground))
        .photosPicker(
            isPresented: $showPhotosPicker,
            selection: $photoPickerItems,
            maxSelectionCount: max(ReviewNoteDraft.maxPhotos - note.photos.count, 0),
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
        .popover(isPresented: $showPhotoOptions, attachmentAnchor: .point(.center), arrowEdge: .top) {
            VStack(alignment: .leading, spacing: 16) {
                Button {
                    showPhotoOptions = false
                    showPhotosPicker = true
                } label: {
                    Label("Choose Existing".localized, systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.plain)

                if CameraPicker.isAvailable {
                    Button {
                        showPhotoOptions = false
                        showCamera = true
                    } label: {
                        Label("Take New Photo".localized, systemImage: "camera")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .presentationCompactAdaptation(.popover)
        }
    }

    private func loadPhotos(from items: [PhotosPickerItem]) async {
        for item in items {
            guard note.canAddMorePhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                addPhoto(from: image)
            }
        }
    }

    private func addPhoto(from image: UIImage) {
        note.addPhoto(from: image)
    }
}
