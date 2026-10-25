import SwiftUI
import UIKit

/// Settings → Notifications: three switches saved on the profile (shared `NotificationsModel`).
/// When iOS blocks Rollspot's notifications, a notice links to the system page instead.
/// Android: NotificationsSettingsScreen.kt.
struct NotificationsSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var languageManager: LanguageManager
    @ObservedObject private var notifications = PushNotificationsService.shared

    var body: some View {
        let state = notifications.state
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if state.isBlocked {
                    blockedNotice
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                VStack(spacing: 0) {
                    toggleRow(
                        title: "Reviews at places you saved",
                        subtitle: "When someone reviews a place you saved",
                        isOn: state.settings.savedPlaceReviews
                    ) { on in await notifications.setSavedPlaceReviews(on) }
                    Divider().padding(.leading, 16)
                    toggleRow(
                        title: "Review reminders",
                        subtitle: "A nudge to finish a review you started",
                        isOn: state.settings.reviewReminders
                    ) { on in await notifications.setReviewReminders(on) }
                    Divider().padding(.leading, 16)
                    toggleRow(
                        title: "News from Rollspot",
                        subtitle: "New places, cities and features",
                        isOn: state.settings.announcements
                    ) { on in await notifications.setAnnouncements(on) }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.05), radius: 8, y: 3)
                )
                .opacity(state.isBlocked ? 0.5 : 1)

                if let error = state.error {
                    Text(error.localized)
                        .font(.footnote)
                        .foregroundStyle(Color(red: 0.72, green: 0.16, blue: 0.18))
                        .padding(.horizontal, 4)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
            .animation(.easeOut(duration: 0.2), value: state.isBlocked)
            .animation(.easeOut(duration: 0.2), value: state.error)
        }
        .background(Color.mockSectionBackground)
        .navigationTitle("Notifications".localized)
        .navigationBarTitleDisplayMode(.large)
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
                .accessibilityLabel("Back".localized)
            }
        }
        .task { await notifications.refreshPermission() }
    }

    private var blockedNotice: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "bell.slash.fill")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.blue)
                    .frame(width: 24, height: 24)
                Text("Notifications are turned off for Rollspot in your phone's settings.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button {
                if let url = URL(string: UIApplication.openNotificationSettingsURLString) { openURL(url) }
            } label: {
                Text("Open Settings".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Capsule().fill(Color(designHex: 0x0099FE)))
            }
            .buttonStyle(PressableButtonStyle())
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(designHex: 0xE4F5FF))
        )
    }

    private func toggleRow(
        title: String,
        subtitle: String,
        isOn: Bool,
        onChange: @escaping (Bool) async -> Void
    ) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.localized)
                    .font(.body)
                    .foregroundStyle(.primary)
                Text(subtitle.localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Toggle(
                title.localized,
                isOn: Binding(get: { isOn }, set: { on in Task { await onChange(on) } })
            )
            .labelsHidden()
            .tint(Color(designHex: 0x0099FE))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { NotificationsSettingsView() }
        .environmentObject(LanguageManager.shared)
}
