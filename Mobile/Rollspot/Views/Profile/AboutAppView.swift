import SwiftUI

struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                aboutSection(
                    title: "What is Rollspot?".localized,
                    body: "About Rollspot summary".localized
                )

                aboutSection(
                    title: "What the app does".localized,
                    body: "About app features summary".localized
                )

                aboutSection(
                    title: "Who it's for".localized,
                    body: "About audience summary".localized
                )

                aboutSection(
                    title: "Why it matters".localized,
                    body: "About why it matters summary".localized
                )

                aboutSection(
                    title: "What makes us different".localized,
                    body: "About differentiation summary".localized
                )
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
        .navigationTitle("About App".localized)
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
    }

    private func aboutSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.primary)

            Text(body)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        AboutAppView()
            .environmentObject(LanguageManager.shared)
    }
}
