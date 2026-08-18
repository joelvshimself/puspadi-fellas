import SwiftUI

struct ContributeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)

            Text("Contribute")
                .font(.title2.bold())

            Text("TODO: Contribution flow will appear here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Demo entry point for the mockup screens (Place Details /
            // Gallery / My Review) — mock data only, no backend wiring yet.
            NavigationLink {
                MockPlaceDetailView()
            } label: {
                Text("Preview: Place Details Mockup")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color.accentColor, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
        .navigationTitle("Contribute")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        ContributeView()
    }
}
