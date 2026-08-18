import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    
    @State private var selectedTab: ProfileTab
    @State private var userName: String = "Aarief M."
    
    init(initialTab: ProfileTab = .reviews) {
        _selectedTab = State(initialValue: initialTab)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header content
            VStack(spacing: 12) {
                // User Avatar
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 72, height: 72)
                    .foregroundStyle(Color.gray.opacity(0.4))
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    .padding(.top, 4)
                
                // Name & Badge
                VStack(spacing: 6) {
                    Text(userName)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.blue)
                        
                        Text("Top Contributor".localized)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.blue)
                        
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.blue.opacity(0.8))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.08))
                    )
                }
                
                // Segmented Tab Picker
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
                    colors: [Color.blue.opacity(0.12), Color(uiColor: .systemGroupedBackground)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            // Tab Content Body
            Group {
                switch selectedTab {
                case .reviews:
                    ProfileReviewsView()
                case .photos:
                    ProfilePhotosView()
                case .settings:
                    ProfileSettingsView(onBackToHome: {
                        dismiss()
                    })
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
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
    }
}

#Preview {
    NavigationStack {
        ProfileView()
            .environmentObject(LanguageManager.shared)
    }
}
