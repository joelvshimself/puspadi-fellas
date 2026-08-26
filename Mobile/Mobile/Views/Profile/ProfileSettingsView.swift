import SwiftUI

struct ProfileSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    @State private var showLanguageSheet = false
    @State private var pseudonym: String?
    @State private var realName: String?
    @State private var showRealName = false
    /// Guards the toggle's own write from re-triggering it when the initial
    /// load sets the state.
    @State private var privacyLoaded = false

    private static let testFlightURL = URL(string: "https://testflight.apple.com/join/BkzVVnrt")!

    var onBackToHome: (() -> Void)? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                settingsCard {
                    NavigationLink {
                        MyAccountView(onBackToHome: onBackToHome)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Color.blue)
                                .frame(width: 24, height: 24)

                            Text("My Account".localized)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Spacer()

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
                .padding(.top, 12)

                privacyCard

                settingsCard {
                    settingsRow(
                        icon: "globe",
                        title: "Language".localized,
                        value: languageManager.currentLanguage.rawValue.localized
                    ) {
                        showLanguageSheet = true
                    }
                    Divider().padding(.leading, 52)

                    NavigationLink {
                        AboutAppView()
                    } label: {
                        settingsRowLabel(icon: "info.circle.fill", title: "About App".localized)
                    }
                    .buttonStyle(.plain)

                    Divider().padding(.leading, 52)

                    Button {
                        openURL(Self.testFlightURL)
                    } label: {
                        settingsRowLabel(icon: "bubble.left.and.bubble.right.fill", title: "Give Feedback".localized)
                    }
                    .buttonStyle(.plain)
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
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(Color.mockSectionBackground)
        .task {
            guard !privacyLoaded else { return }
            if let profile = try? await ProfileService.shared.fetchCurrent() {
                pseudonym = profile.pseudonym
                realName = profile.displayName
                showRealName = profile.showRealName ?? false
            }
            privacyLoaded = true
        }
        .onChange(of: showRealName) { _, newValue in
            // Only after the initial load — otherwise setting the state from
            // the fetched profile would immediately write it straight back.
            guard privacyLoaded else { return }
            Task { try? await ProfileService.shared.updateShowRealName(newValue) }
        }
        .sheet(isPresented: $showLanguageSheet) {
            languageSheet
                .presentationDetents([.height(240)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
    }

    /// How this account is credited on the reviews other people read.
    ///
    /// Worth a whole card rather than a buried row: a review card sits next to
    /// a statement about the writer's disability and photographs of where they
    /// have been, and the person writing it deserves to know which name is on
    /// it — and to be able to change their mind.
    private var privacyCard: some View {
        settingsCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Image(systemName: "theatermasks")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color.blue)
                        .frame(width: 24, height: 24)

                    Text("Shown on your reviews".localized)
                        .font(.body)
                        .foregroundStyle(.primary)

                    Spacer()
                }

                Text(showRealName
                     ? (realName ?? "Your name".localized)
                     : (pseudonym ?? "Community".localized))
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.leading, 38)

                Toggle(isOn: $showRealName) {
                    Text("Use my real name instead".localized)
                        .font(.subheadline)
                }
                .padding(.leading, 38)
                .disabled(!privacyLoaded)

                Text("Your reviews are signed with a handle unless you turn this on. Your account is still linked to them either way.".localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 38)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
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
            settingsRowLabel(icon: icon, title: title, value: value)
        }
        .buttonStyle(.plain)
    }

    private func settingsRowLabel(icon: String, title: String, value: String? = nil) -> some View {
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
}

#Preview {
    ProfileSettingsView()
        .environmentObject(LanguageManager.shared)
        .environmentObject(AuthSessionStore())
}
