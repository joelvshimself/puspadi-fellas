import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var showLanguageSheet = false
    @State private var showDeleteAccountSheet = false
    @State private var isAccountDeleted = false
    @State private var feedbackText = ""

    var onBackToHome: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                settingsCard {
                    settingsRow(icon: "person.fill", title: "My Account".localized)
                }
                .padding(.top, 12)

                settingsCard {
                    settingsRow(
                        icon: "globe",
                        title: "Language".localized,
                        value: languageManager.currentLanguage.rawValue.localized
                    ) {
                        showLanguageSheet = true
                    }
                    Divider().padding(.leading, 52)

                    settingsRow(icon: "bell.fill", title: "Notifications".localized)
                    Divider().padding(.leading, 52)

                    settingsRow(icon: "info.circle.fill", title: "About App".localized)
                    Divider().padding(.leading, 52)

                    settingsRow(icon: "bubble.left.and.bubble.right.fill", title: "Give Feedback".localized)
                }

                Button {
                    Task {
                        await auth.signOut()
                        dismiss()
                        onBackToHome?()
                    }
                } label: {
                    Text("Sign Out".localized)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(uiColor: .systemBackground))
                        )
                }
                .padding(.top, 8)

                Button {
                    showDeleteAccountSheet = true
                } label: {
                    Text("Delete Account".localized)
                        .font(.body.weight(.bold))
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.18))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color.red.opacity(0.14))
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.mockSectionBackground)
        .sheet(isPresented: $showLanguageSheet) {
            languageSheet
                .presentationDetents([.height(240)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            deleteAccountSheet
                .presentationDetents([.height(240)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $isAccountDeleted) {
            accountDeletedView
        }
    }

    private func settingsCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            content()
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
        )
    }

    private func settingsRow(icon: String, title: String, value: String? = nil, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.blue)
                    .frame(width: 24, height: 24)

                Text(title)
                    .font(.body)
                    .foregroundStyle(.primary)

                Spacer()

                if let value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var languageSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Language".localized)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)
                .padding(.horizontal, 20)
                .padding(.top, 8)

            VStack(spacing: 10) {
                languageOptionRow(label: "English", appLanguage: .english)
                languageOptionRow(label: "Indonesia", appLanguage: .indonesia)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private func languageOptionRow(label: String, appLanguage: AppLanguage) -> some View {
        let isSelected = (languageManager.currentLanguage == appLanguage)
        return Button {
            withAnimation {
                languageManager.currentLanguage = appLanguage
            }
            showLanguageSheet = false
        } label: {
            HStack {
                Text(label)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.blue : Color.primary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.blue.opacity(0.06) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var deleteAccountSheet: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Delete Account?".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Deleting your account will permanently remove it along with all your reviews. This action is irreversible.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            HStack(spacing: 12) {
                Button {
                    showDeleteAccountSheet = false
                } label: {
                    Text("Cancel".localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color(uiColor: .systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }

                Button {
                    showDeleteAccountSheet = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        isAccountDeleted = true
                    }
                } label: {
                    Text("Delete".localized)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.red)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.red.opacity(0.15))
                        )
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    private var accountDeletedView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.15), Color(uiColor: .systemBackground)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()
                    Button {
                        Task {
                            await auth.signOut()
                            isAccountDeleted = false
                            dismiss()
                            onBackToHome?()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.secondary)
                            .padding(10)
                            .background(Circle().fill(.thinMaterial))
                    }
                }
                .padding(.horizontal, 20)

                Spacer()

                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 80, height: 80)
                    .foregroundStyle(Color.green)

                VStack(spacing: 8) {
                    Text("Account Deleted".localized)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.primary)

                    Text("We are sorry to hear you go... Tell us more about your experience for us to improve".localized)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 32)

                TextField("Your feedbacks here (Optional)".localized, text: $feedbackText, axis: .vertical)
                    .font(.body)
                    .lineLimit(4...6)
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)

                Spacer()

                Button {
                    Task {
                        await auth.signOut()
                        isAccountDeleted = false
                        dismiss()
                        onBackToHome?()
                    }
                } label: {
                    Text("Back to Home".localized)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            Capsule()
                                .fill(Color.blue)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}

#Preview {
    ProfileSettingsView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(AuthSessionStore())
}
