import PhotosUI
import SwiftUI

struct ProfilePhotosView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var photos: [FacilityPhoto] = []
    @State private var selectedPhoto: FacilityPhoto? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isUploading = false

    var body: some View {
        ZStack(alignment: .top) {
            Color.mockSectionBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("\("All Photos".localized) (\(photos.count))")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)

                        Spacer()

                        PhotosPicker(selection: $selectedPhotoItems, matching: .images) {
                            HStack(spacing: 6) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 13, weight: .bold))
                                Text("ADD PHOTOS".localized)
                                    .font(.caption.weight(.bold))
                            }
                            .foregroundStyle(AuthPalette.brandBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(Color(uiColor: .systemBackground))
                                    .shadow(color: .black.opacity(0.06), radius: 4, y: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    if photos.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 40, weight: .light))
                                .foregroundStyle(.secondary)
                            Text("No Photos Yet".localized)
                                .font(.headline)
                            Text("Photos you add to reviews will show up here.".localized)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 24)
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(photos) { photo in
                                Button {
                                    selectedPhoto = photo
                                } label: {
                                    ZStack(alignment: .bottom) {
                                        FacilityPhotoImage(photo: photo, cornerRadius: 16)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 220)
                                        if let caption = photo.caption {
                                            PhotoCaptionOverlay(
                                                caption: caption,
                                                fontSize: 13,
                                                lineLimit: 3
                                            )
                                        }
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }
        }
        .task(id: auth.userId) {
            await loadPhotosFromSupabase()
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FacilityPhotoDetailView(photo: photo)
        }
    }

    private func loadPhotosFromSupabase() async {
        guard auth.userId != nil else {
            await MainActor.run { photos = [] }
            return
        }
        do {
            let response = try await ReviewService.shared.fetchMyReviews()
            let loaded = response.reviews.flatMap(\.facilityPhotos)
            await MainActor.run { self.photos = loaded }
        } catch {
            print("ProfilePhotosView: Failed to load photos from Supabase: \(error)")
        }
    }
}

#Preview {
    ProfilePhotosView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(AuthSessionStore())
}
