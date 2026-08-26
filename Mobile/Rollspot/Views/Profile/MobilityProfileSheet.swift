import SwiftUI

struct MobilityProfileSheet: View {
    var selected: MobilityProfile?
    var onSelect: (MobilityProfile) async throws -> Void

    @State private var draft: MobilityProfile?
    @State private var isSaving = false
    @State private var errorMessage: String?

    /// Matches the Figma sheet chrome: 34 top / 58 bottom.
    static let sheetShape = UnevenRoundedRectangle(
        topLeadingRadius: 34,
        bottomLeadingRadius: 58,
        bottomTrailingRadius: 58,
        topTrailingRadius: 34,
        style: .continuous
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mobility Profile".localized)
                .font(.title3.weight(.bold))
                .foregroundStyle(.primary)

            VStack(spacing: 10) {
                optionCard(
                    profile: .wheelchairUser,
                    title: "Wheelchair User".localized,
                    description: {
                        Text("Firsthand experience using a wheelchair".localized)
                            .font(.footnote)
                            .foregroundStyle(currentSelection == .wheelchairUser
                                ? AuthPalette.brandBlue.opacity(0.85)
                                : .secondary)
                    }
                )

                optionCard(
                    profile: .communityContributor,
                    title: "Community Contributor".localized,
                    description: {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("• \("User with other mobility aid".localized)")
                            Text("• \("User with no mobility aid".localized)")
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                )
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(AuthPalette.errorRed)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .padding(.bottom, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay {
            if isSaving {
                ProgressView()
            }
        }
        .onAppear { draft = selected }
    }

    private var currentSelection: MobilityProfile? { draft ?? selected }

    private func optionCard<Description: View>(
        profile: MobilityProfile,
        title: String,
        @ViewBuilder description: () -> Description
    ) -> some View {
        let isSelected = currentSelection == profile
        return Button {
            Task { await choose(profile) }
        } label: {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? AuthPalette.brandBlue : .primary)

                    description()
                }

                Spacer(minLength: 8)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? AuthPalette.brandBlue : Color.secondary.opacity(0.55))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected
                          ? AuthPalette.brandBlue.opacity(0.08)
                          : Color(uiColor: .systemBackground))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        isSelected ? AuthPalette.brandBlue : Color.clear,
                        lineWidth: 1.5
                    )
            }
        }
        .buttonStyle(.plain)
        .disabled(isSaving)
    }

    private func choose(_ profile: MobilityProfile) async {
        draft = profile
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await onSelect(profile)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    MobilityProfileSheet(selected: .wheelchairUser) { _ in }
}

/// Applies 34/58 sheet chrome on OS versions without liquid glass asymmetry.
struct MobilitySheetPresentationChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
        } else {
            content
                .presentationBackground {
                    MobilityProfileSheet.sheetShape
                        .fill(Color(uiColor: .secondarySystemBackground))
                }
        }
    }
}
