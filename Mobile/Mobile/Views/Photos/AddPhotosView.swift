import PhotosUI
import SwiftUI

/// "Add Photos" composer (node 553:22988) — a two-column tray of everything the
/// user has staged, with a dashed Browse tile in the first slot, a remove
/// button on every photo, and Submit pinned to the bottom.
///
/// Presented full-screen from `FacilityPhotosView` once a source has been
/// picked, so it opens already holding that first selection.
struct AddPhotosView: View {
    /// Photos carried in from the Choose Existing / Take New Photo step.
    let initialPhotos: [FacilityPhoto]
    let onSubmit: ([FacilityPhoto]) -> Void
    let onBack: () -> Void

    /// No design constraint on this; a soft cap so one submission can't stage
    /// an unbounded number of images.
    static let maxPhotos = 10

    @State private var photos: [FacilityPhoto] = []
    @State private var browseSelection: [PhotosPickerItem] = []
    @State private var didSeed = false

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "Add Photos", onBack: onBack)

            ScrollView {
                grid
                    .padding(.horizontal, PhotoMetrics.composerHorizontalPadding)
                    .padding(.bottom, PhotoMetrics.submitTopSpacing)
            }

            submitButton
                .padding(.horizontal, PhotoMetrics.composerHorizontalPadding)
                .padding(.bottom, 20)
        }
        .background(Color(.systemBackground))
        .onAppear {
            // Seed once — re-entering the cover shouldn't duplicate the tray.
            guard !didSeed else { return }
            didSeed = true
            photos = Array(initialPhotos.prefix(Self.maxPhotos))
        }
        .onChange(of: browseSelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await appendPickedPhotos(newItems)
                browseSelection = []
            }
        }
    }

    private var grid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: PhotoMetrics.composerSpacing),
                GridItem(.flexible(), spacing: PhotoMetrics.composerSpacing),
            ],
            spacing: PhotoMetrics.composerSpacing
        ) {
            browseTile
            ForEach(photos) { photo in
                photoTile(photo)
            }
        }
    }

    private var browseTile: some View {
        PhotosPicker(
            selection: $browseSelection,
            maxSelectionCount: max(Self.maxPhotos - photos.count, 1),
            matching: .images
        ) {
            VStack(spacing: PhotoMetrics.composerSpacing) {
                Image(systemName: "photo.badge.plus.fill")
                    .font(.system(size: 30))
                    .foregroundStyle(PhotoPalette.brandBlue)
                Text("Browse")
                    .font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .medium))
                    .foregroundStyle(PhotoPalette.brandBlue)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: PhotoMetrics.browseCornerRadius, style: .continuous)
                    .fill(PhotoPalette.background1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: PhotoMetrics.browseCornerRadius, style: .continuous)
                    .strokeBorder(
                        PhotoPalette.tertiaryBlue,
                        style: StrokeStyle(lineWidth: PhotoMetrics.browseBorderWidth, dash: [8, 6])
                    )
            )
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(.plain)
        .disabled(photos.count >= Self.maxPhotos)
        .opacity(photos.count >= Self.maxPhotos ? 0.5 : 1)
    }

    private func photoTile(_ photo: FacilityPhoto) -> some View {
        ZStack(alignment: .topTrailing) {
            FacilityPhotoImage(photo: photo, cornerRadius: PhotoMetrics.composerTileCornerRadius)

            Button {
                photos.removeAll { $0.id == photo.id }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(PhotoPalette.primaryLabel)
                    .frame(width: PhotoMetrics.removeButtonSize, height: PhotoMetrics.removeButtonSize)
                    .background(Circle().fill(PhotoPalette.background1))
                    // drop-shadow 0 4.048 6.528 rgba(0,0,0,0.25).
                    .shadow(color: .black.opacity(0.25), radius: 3.264, y: 4.048)
            }
            .buttonStyle(.plain)
            .padding(PhotoMetrics.removeButtonInset)
            .accessibilityLabel("Remove photo")
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private var submitButton: some View {
        Button {
            onSubmit(photos)
        } label: {
            Text("Submit")
                .font(.system(size: PhotoMetrics.addPhotosLabelSize, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: PhotoMetrics.submitHeight)
                .background(Capsule().fill(PhotoPalette.brandBlue))
        }
        .buttonStyle(.plain)
        .disabled(photos.isEmpty)
        .opacity(photos.isEmpty ? 0.5 : 1)
    }

    @MainActor
    private func appendPickedPhotos(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard photos.count < Self.maxPhotos else { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                photos.append(FacilityPhoto(image: image))
            }
        }
    }
}

#Preview {
    AddPhotosView(
        initialPhotos: Array(FacilityPhoto.samples.prefix(5)),
        onSubmit: { _ in },
        onBack: {}
    )
}
