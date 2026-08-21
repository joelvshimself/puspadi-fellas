import SwiftUI

struct MyAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var auth: AuthSessionStore

    var onBackToHome: (() -> Void)? = nil

    @State private var email = ""
    @State private var mobilityProfile: MobilityProfile?
    @State private var showMobilitySheet = false
    @State private var showDeleteAccountSheet = false
    @State private var isAccountDeleted = false
    @State private var feedbackText = ""
    @State private var isLoading = true
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                accountField(
                    label: "Email".localized,
                    value: email.isEmpty ? "—" : email
                )

                mobilityField

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
                .padding(.top, 8)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
        .background(
            LinearGradient(
                colors: [
                    Color(red: 0.72, green: 0.88, blue: 1.0).opacity(0.55),
                    Color(uiColor: .systemBackground),
                    Color(uiColor: .systemBackground)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .navigationTitle("My Account".localized)
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
            }
        }
        .task { await loadAccount() }
        .sheet(isPresented: $showMobilitySheet) {
            MobilityProfileSheet(selected: mobilityProfile) { profile in
                try await auth.updateMobilityProfile(profile)
                await MainActor.run {
                    mobilityProfile = profile
                    showMobilitySheet = false
                    errorMessage = nil
                }
            }
            .presentationDetents([.height(248)])
            .presentationDragIndicator(.visible)
            .modifier(MobilitySheetPresentationChrome())
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
        .overlay {
            if isLoading {
                ProgressView()
            }
        }
    }

    private var mobilityField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mobility Profile".localized)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Button {
                showMobilitySheet = true
            } label: {
                HStack {
                    Text((mobilityProfile?.titleKey ?? "Not set").localized)
                        .font(.body)
                        .foregroundStyle(mobilityProfile == nil ? .tertiary : .secondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AuthPalette.fieldFill)
                )
            }
            .buttonStyle(.plain)

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(AuthPalette.errorRed)
            }
        }
    }

    private var deleteAccountSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Delete Account?".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Deleting your account will permanently remove it along with all your reviews. This action is irreversible.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var accountDeletedView: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
                                .fill(AuthPalette.brandBlue)
                        )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    private func accountField(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            Text(value)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(AuthPalette.fieldFill)
                )
        }
    }

    private func loadAccount() async {
        isLoading = true
        defer { isLoading = false }
        email = auth.userEmail ?? ""
        do {
            let row = try await ProfileService.shared.fetchCurrent()
            mobilityProfile = MobilityProfile.from(aids: row?.mobilityAids)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        MyAccountView()
            .environmentObject(AuthSessionStore())
            .environmentObject(LanguageManager.shared)
    }
}
