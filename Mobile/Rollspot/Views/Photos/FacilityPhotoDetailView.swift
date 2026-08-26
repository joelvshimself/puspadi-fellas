import SwiftUI

/// Full-screen lightbox — swipe horizontally among photos from the same review,
/// with pinch / double-tap zoom on the current photo.
struct FacilityPhotoDetailView: View {
    let photos: [FacilityPhoto]
    let initialID: UUID

    @Environment(\.dismiss) private var dismiss
    @State private var currentID: UUID?
    @State private var isZoomed = false

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
                ZoomableFacilityPhotoPage(photo: photo, isZoomed: $isZoomed)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(photos) { photo in
                            ZoomableFacilityPhotoPage(
                                photo: photo,
                                isZoomed: Binding(
                                    get: { currentID == photo.id && isZoomed },
                                    set: { newValue in
                                        if currentID == photo.id || currentID == nil {
                                            isZoomed = newValue
                                        }
                                    }
                                )
                            )
                            .containerRelativeFrame(.horizontal)
                            .id(photo.id)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $currentID)
                .scrollTargetBehavior(.paging)
                .scrollDisabled(isZoomed)
            }

            VStack(spacing: 0) {
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
                .padding(.top, 20)
                .padding(.horizontal, 20)

                Spacer()
                    .allowsHitTesting(false)
            }
        }
        .presentationBackground(.black)
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    if value.translation.height > 80 { dismiss() }
                },
            // Ignore swipe-down dismiss while zoomed so it does not fight pan.
            including: isZoomed ? .none : .gesture
        )
        .onChange(of: currentID) { _, _ in
            isZoomed = false
        }
        .animation(.easeOut(duration: 0.15), value: isZoomed)
        .animation(.easeOut(duration: 0.15), value: currentID)
    }
}

/// Loads a `FacilityPhoto` into a `UIImage`, then hands it to the zoom container.
private struct ZoomableFacilityPhotoPage: View {
    let photo: FacilityPhoto
    @Binding var isZoomed: Bool

    @State private var image: UIImage?
    @State private var finishedLoading = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image {
                    ZoomablePhotoContainer(image: image, isZoomed: $isZoomed)
                } else if !finishedLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.white.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            if photo.caption != nil, !isZoomed {
                PhotoCaptionBadge()
                    .padding(16)
                    .transition(.opacity)
            }
        }
        .task(id: photo.id) {
            await loadImage()
        }
    }

    private func loadImage() async {
        finishedLoading = false
        image = nil
        isZoomed = false
        defer { finishedLoading = true }

        switch photo.source {
        case let .local(uiImage):
            image = uiImage
        case let .asset(name):
            image = UIImage(named: name)
        case let .remote(url):
            guard let data = try? await NetworkRetry.download(from: url) else { return }
            image = UIImage(data: data)
        }
    }
}

#Preview {
    FacilityPhotoDetailView(
        photo: FacilityPhoto(
            source: .asset("SamplePlacePhoto"),
            caption: "Lobby ramp is on the left side of the main doors."
        )
    )
}
