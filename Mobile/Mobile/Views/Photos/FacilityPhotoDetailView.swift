import SwiftUI

/// Full-screen lightbox for a single facility photo.
struct FacilityPhotoDetailView: View {
    let photo: FacilityPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            FacilityPhotoImage(photo: photo, cornerRadius: 0, fillsFrame: false)
                .padding(20)
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.22), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Close")
                }
                Spacer()
            }
            .padding(20)
        }
        .presentationBackground(.black)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 80 {
                        dismiss()
                    }
                }
        )
    }
}

#Preview {
    FacilityPhotoDetailView(photo: FacilityPhoto.reviewThumbnails[0])
}
