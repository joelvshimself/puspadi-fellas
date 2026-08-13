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

    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add a note")
                    .font(.title2.bold())
                Text("Optional — \(context). Add a photo or note to help other users.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            photoPicker

            VStack(alignment: .leading, spacing: 8) {
                Text("Notes about \(title)")
                    .font(.headline)
                TextField("What should other users know?", text: $note.text, axis: .vertical)
                    .lineLimit(4...8)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
            }
        }
        // TODO(backend): photoImage is kept in memory only for this
        // view-only pass — real flow needs a Supabase Storage upload that
        // produces the `photoUrls: [String]` the contract expects.
        .onChange(of: photoPickerItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    note.photoImage = image
                }
            }
        }
    }

    @ViewBuilder
    private var photoPicker: some View {
        PhotosPicker(selection: $photoPickerItem, matching: .images) {
            if let image = note.photoImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 160)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "camera.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Add Photo")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 120)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color(.separator), style: StrokeStyle(lineWidth: 1, dash: [6]))
                )
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ReviewAddNoteStepView(title: "Lobby entrance", context: "tell us more about the lobby entrance", note: .constant(ReviewNoteDraft()))
        .padding()
}
