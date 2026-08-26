import SwiftUI

/// Full-screen lightbox — swipe horizontally among photos from the same review.
struct FacilityPhotoDetailView: View {
    let photos: [FacilityPhoto]
    let initialID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var currentID: UUID

    init(photos: [FacilityPhoto], initialID: UUID) {
        self.photos = photos
        self.initialID = initialID
        _currentID = State(initialValue: initialID)
    }

    /// Single-photo convenience (no horizontal swipe).
    init(photo: FacilityPhoto) {
        self.init(photos: [photo], initialID: photo.id)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if photos.count <= 1, let photo = photos.first {
                FacilityPhotoImage(photo: photo, cornerRadius: 0, fillsFrame: false)
                    .padding(20)
            } else {
                TabView(selection: $currentID) {
                    ForEach(photos) { photo in
                        FacilityPhotoImage(photo: photo, cornerRadius: 0, fillsFrame: false)
                            .padding(20)
                            .tag(photo.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }

            VStack {
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(.white.opacity(0.22), in: Circle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(20)
        }
        .presentationBackground(.black)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 80 { dismiss() }
                }
        )
    }
}

#Preview {
    FacilityPhotoDetailView(photo: FacilityPhoto.reviewThumbnails[0])
}
