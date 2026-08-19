import PhotosUI
import SwiftUI

/// Optional "add a note" add-on — reused after Lobby, Basement, Elevator, and
/// Toilet. `title` names the screen ("Lobby entrance", "Elevator", ...) and
/// `context` clarifies what the note is about, so it's clear which facility
/// this photo/text is attached to before it's bundled into that facility's
/// `review` field in the payload. Always skippable; Next stays enabled
/// regardless of content.
struct ReviewAddNoteStepView: View {
    let title: String
    let context: String
    @Binding var note: ReviewNoteDraft

    @State private var photoPickerItems: [PhotosPickerItem] = []
    @FocusState private var notesFocused: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Add a note".localized)
                            .font(.title2.bold())
                        Text("\("Optional".localized) — \(context.localized). \("Add photos or a note to help other users.".localized)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    photoSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("\("Notes about".localized) \(title.localized)")
                            .font(.headline)
                        TextField("What should other users know?".localized, text: $note.text, axis: .vertical)
                            .lineLimit(4...8)
                            .focused($notesFocused)
                            .padding(14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                    }
                    .id("notesSection")
                }
                .padding(20)
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
        .contentShape(Rectangle())
        .onTapGesture {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
        .onChange(of: photoPickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                await loadPhotos(from: newItems)
                photoPickerItems = []
            }
        }
    }

    @ViewBuilder
    private var photoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !note.photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(note.photos) { photo in
                            photoThumbnail(photo)
                        }
                    }
                }
            }

            if note.canAddMorePhotos {
                PhotosPicker(
                    selection: $photoPickerItems,
                    maxSelectionCount: ReviewNoteDraft.maxPhotos - note.photos.count,
                    matching: .images
                ) {
                    addPhotosLabel
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addPhotosLabel: some View {
        VStack(spacing: 8) {
            Image(systemName: "camera.fill")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text(note.photos.isEmpty ? "Add Photos".localized : "Add More Photos".localized)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("Up to \(ReviewNoteDraft.maxPhotos)".localized)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [6]))
        )
    }

    private func photoThumbnail(_ photo: ReviewPhotoDraft) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFill()
                .frame(width: 112, height: 112)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

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
    ReviewAddNoteStepView(
        title: "Lobby entrance",
        context: "tell us more about the lobby entrance",
        note: .constant(ReviewNoteDraft())
    )
    .padding()
}
