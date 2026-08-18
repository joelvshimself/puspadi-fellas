import SwiftUI

struct SavedView: View {
    var body: some View {
        List {
            // Mock-data-only demo row (Park23 Mall) — connects to the
            // Place Details / Gallery / My Review mockup screens
            // (Views/Detail/Mock, Views/Gallery/Mock). This is a real
            // saved place until the bookmark backend exists, at which
            // point this row is replaced by actual saved-place data.
            NavigationLink {
                MockPlaceDetailView()
            } label: {
                HStack(spacing: 12) {
                    Image("Park23 Image")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 52, height: 52)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(MockData.placeName)
                            .font(.body.weight(.semibold))
                        Text("Reviewed at \(MockData.review.reviewedDateLabel)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SavedView()
    }
}
