import CoreLocation
import SwiftUI

struct FacilityReviewedOverview: View {
    let kind: FacilityKind
    var showsUserReview: Bool = true
    @State private var selectedPhoto: FacilityPhoto?
    @State private var showContributeFlow = false

    /// No `Place` reaches this screen today — same throwaway-`Place`
    /// pattern used elsewhere (MockPlaceDetailView, NotReviewView).
    private var contributePlace: Place {
        Place.fromSearchResult(
            name: MockData.placeName,
            category: "Mall",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section(title: "What provided") {
                FlowRow(spacing: 10) {
                    ForEach(kind.reviewedProvidedItems, id: \.label) { item in
                        HStack(spacing: 6) {
                            Image(systemName: item.symbol)
                                .font(.caption)
                            Text(item.label)
                                .font(.caption.weight(.semibold))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray5), in: Capsule())
                    }
                }
            }

            section(title: "Notes from reviews", contentInsets: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(kind.reviewNotes.enumerated()), id: \.offset) { index, note in
                        if index > 0 {
                            Divider()
                        }
                        HStack {
                            Text(note)
                                .font(.subheadline)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                }
            }

            if showsUserReview {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Your Review")
                            .font(.headline)
                        Spacer()
                        Button("Update Review") { showContributeFlow = true }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                    }

                    FacilityReviewRow(
                        bodyText: kind.reviewBody,
                        providedList: kind.reviewProvidedList,
                        onSelectPhoto: { selectedPhoto = $0 }
                    )
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color.white)
                    )
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Find something different?")
                        .font(.title3.bold())

                    Button {
                        showContributeFlow = true
                    } label: {
                        Text("Add New Review")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor, in: Capsule())
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FacilityPhotoDetailView(photo: photo)
        }
        .fullScreenCover(isPresented: $showContributeFlow) {
            ContributeReviewFlowView(place: contributePlace, startingFacility: kind) {
                showContributeFlow = false
            }
        }
    }

    private func section<Content: View>(
        title: String,
        contentInsets: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
            content()
                .padding(contentInsets)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white)
                )
        }
    }
}

#Preview {
    ScrollView {
        FacilityReviewedOverview(kind: .entrance)
            .padding()
    }
    .background(Color(.systemGroupedBackground))
}
