import PhotosUI
import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var selectedTab: ProfileTab
    @State private var userName: String = ""
    @State private var avatarURL: URL?
    @State private var mobilityProfile: MobilityProfile?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isUploadingAvatar = false

    init(initialTab: ProfileTab = .reviews) {
        _selectedTab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    ZStack(alignment: .bottomTrailing) {
                        ZStack {
                            avatarView
                            if isUploadingAvatar {
                                Circle()
                                    .fill(Color.black.opacity(0.35))
                                    .frame(width: 88, height: 88)
                                ProgressView()
                                    .tint(.white)
                            }
                        }

                        if !isUploadingAvatar {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(white: 0.38))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(Color(uiColor: .systemGray6))
                                        .shadow(color: .black.opacity(0.16), radius: 3, y: 1)
                                )
                                .offset(x: 2, y: 2)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Change profile photo".localized)
                .padding(.top, 4)

                VStack(spacing: 6) {
                    Text(userName.isEmpty ? " " : userName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    if let mobilityProfile {
                        Text(mobilityProfile.titleKey.localized)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                Capsule()
                                    .fill(Color.gray.opacity(0.18))
                            )
                    }
                }

                HStack(spacing: 4) {
                    ForEach(ProfileTab.allCases) { tab in
                        let isSelected = (selectedTab == tab)
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                selectedTab = tab
                            }
                        } label: {
                            Text(tab.localizedTitle)
                                .font(.caption.weight(.bold))
                                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                                .frame(maxWidth: .infinity)
                                .frame(height: 36)
                                .background(
                                    Group {
                                        if isSelected {
                                            Capsule()
                                                .fill(Color(uiColor: .systemBackground))
                                                .shadow(color: .black.opacity(0.08), radius: 4, y: 1)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.12))
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
            }
            .padding(.bottom, 12)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.72, green: 0.88, blue: 1.0),
                        Color.white,
                        Color.mockSectionBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )

            Group {
                switch selectedTab {
                case .reviews:
                    ProfileReviewsView(
                        displayName: userName,
                        avatarURL: avatarURL,
                        mobilityLabel: mobilityProfile?.titleKey.localized ?? ""
                    )
                case .photos:
                    ProfilePhotosView()
                case .settings:
                    ProfileSettingsView(onBackToHome: {
                        dismiss()
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.mockSectionBackground)
        }
        .background(Color.mockSectionBackground.ignoresSafeArea())
        .navigationTitle("Profile".localized)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                }
            }
        }
        .task {
            await loadProfile()
        }
        .onChange(of: selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await uploadAvatar(from: item) }
        }
    }

    @ViewBuilder
    private var avatarView: some View {
        if let avatarURL {
            AsyncImage(url: avatarURL) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                default:
                    placeholderAvatar
                }
            }
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        } else {
            placeholderAvatar
        }
    }

    private var placeholderAvatar: some View {
        Image("Profile Avatar")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 88, height: 88)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.white, lineWidth: 2))
            .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
    }

    private func loadProfile() async {
        do {
            if let row = try await ProfileService.shared.fetchCurrent() {
                await MainActor.run {
                    userName = (row.displayName?.isEmpty == false) ? row.displayName! : "You"
                    avatarURL = row.avatarUrl.flatMap(URL.init(string:))
                    mobilityProfile = MobilityProfile.from(aids: row.mobilityAids)
                }
            }
        } catch {
            print("ProfileView: failed to load profile: \(error)")
        }
    }

    private func uploadAvatar(from item: PhotosPickerItem) async {
        isUploadingAvatar = true
        defer {
            isUploadingAvatar = false
            selectedPhotoItem = nil
        }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data),
              let jpeg = image.jpegData(compressionQuality: 0.85)
        else { return }
        do {
            let urlString = try await ProfileService.shared.uploadAvatar(jpegData: jpeg)
            await MainActor.run {
                avatarURL = URL(string: urlString)
            }
        } catch {
            print("ProfileView: avatar upload failed: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(LanguageManager.shared)
            .environmentObject(AuthSessionStore())
    }
}
