import SwiftUI

struct ProfilePhotosView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var remotePhotoURLs: [URL] = []
    @State private var selectedPhoto: FacilityPhoto? = nil

    var body: some View {
        ZStack(alignment: .top) {
            Color.mockSectionBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\("All Photos".localized) (\(remotePhotoURLs.count))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, PhotoMetrics.gutter)
                        .padding(.top, 12)

                    if remotePhotoURLs.isEmpty {
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
                            ForEach(remotePhotoURLs, id: \.self) { url in
                                Button {
                                    selectedPhoto = FacilityPhoto(source: .remote(url))
                                } label: {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case .success(let image):
                                            image
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                        default:
                                            Color(.secondarySystemBackground)
                                                .overlay { ProgressView() }
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 220)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, PhotoMetrics.gutter)
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
            await MainActor.run { remotePhotoURLs = [] }
            return
        }
        do {
            let response = try await ReviewService.shared.fetchMyReviews()
            let urls = response.reviews.flatMap(\.photoURLs)
            await MainActor.run { self.remotePhotoURLs = urls }
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
