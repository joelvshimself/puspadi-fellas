import CoreLocation
import SwiftUI

/// Demo "My Review" screen — reached from MockPlaceDetailView's
/// "Thank you for the review!" row (reviewedByMe state). Mock data only;
/// "Update Review" reuses the real `ReviewWizardView` the same way
/// `AnalysingView` is a disconnected demo entry — a throwaway `Place` is
/// enough to satisfy its init since no submission actually happens here.
struct MockMyReviewView: View {
    @State private var selectedTab: MockFacility.ID
    @State private var showReviewWizard = false

    private let review = MockData.review

    init() {
        _selectedTab = State(initialValue: MockData.review.facilityTabs[0].id)
    }

    private var selectedFacility: MockFacility {
        review.facilityTabs.first { $0.id == selectedTab } ?? review.facilityTabs[0]
    }

    private var wizardPlace: Place {
        Place.fromSearchResult(
            name: MockData.placeName,
            category: "Mall",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
    }

    var body: some View {
        // The gray section background is painted on the ScrollView itself
        // (not just reviewContentSection) so it fills all the way to the
        // bottom even when content is shorter than the screen — otherwise
        // a stray white gap shows below Notes. The "Any changes...? /
        // Update Review" row lives inside reviewContentSection now (last
        // row, same gray background), matching the design — it's not a
        // separate pinned white footer bar.
        ScrollView {
            VStack(spacing: 0) {
                placeInfoSection
                reviewContentSection
            }
        }
        // White, matching the nav bar — not gray. Gray only lives on
        // reviewContentSection itself (with its own minHeight fallback
        // below); painting it on the whole ScrollView made pull-to-refresh
        // overscroll show a gray patch floating below the white nav bar,
        // visibly "detached" from it, instead of a clean white rubber-band.
        .background(Color(.systemBackground))
        .navigationTitle("Your Review")
        .navigationBarTitleDisplayMode(.inline)
        // No custom back button — system default matches native look.
        // Explicit white nav bar background — otherwise the bar picks up
        // the scroll-edge material and looks translucent/gray instead of
        // matching the design's plain white top bar.
        .toolbarBackground(Color(.systemBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(isPresented: $showReviewWizard) {
            ReviewWizardView(place: wizardPlace) { showReviewWizard = false }
        }
    }

    // MARK: Place info

    private var placeInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(MockData.placeName)
                    .font(.system(size: 22, weight: .bold))
                Text("Reviewed at \(review.reviewedDateLabel)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }

            Button {
                showReviewWizard = true
            } label: {
                Text("Update Review")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    // MARK: Tabbed content

    private var reviewContentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            FilterSegmentedControl(
                options: review.facilityTabs.map(\.id),
                label: { id in review.facilityTabs.first { $0.id == id }?.title.uppercased() ?? "" },
                selection: $selectedTab,
                style: .whiteTrack
            )

            whatProvidedSection
            photosSection
            notesSection
            anyChangesRow
        }
        .padding(.horizontal, 22)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        // Own gray fill (not the whole ScrollView's) so pull-to-refresh
        // overscroll at the top stays plain white; the minHeight is a
        // generous fallback so short content still colors all the way to
        // the bottom of a typical screen instead of leaving a white gap
        // below Notes/anyChangesRow.
        .frame(minHeight: 600)
        .background(Color.mockSectionBackground)
    }

    private var whatProvidedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What provided")
                .font(.system(size: 18, weight: .bold))

            if let emptyStateText = selectedFacility.emptyStateText {
                Text(emptyStateText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else {
                FlowRow(spacing: 8) {
                    ForEach(selectedFacility.tags) { tag in
                        PillTag(tag: tag, surface: .onWhiteCard)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var photosSection: some View {
        let photos = MockData.photos.filter { $0.facility == selectedFacility.key }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Photos")
                .font(.system(size: 18, weight: .bold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(photos.prefix(4)) { photo in
                        MockPhotoTile(photo: photo)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if photos.count > 4 {
                        ZStack {
                            Color.black.opacity(0.55)
                            Text("+\(photos.count - 4)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 18, weight: .bold))

            Text(review.notes)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Any-changes row

    /// The design has this as the last row of the gray tabbed-content
    /// section, on its own white card — same treatment as Notes — not a
    /// separate pinned white footer bar with a divider, which is what this
    /// used to be, and not a bare row directly on the gray background
    /// either.
    private var anyChangesRow: some View {
        HStack {
            Text("Any changes in the \(selectedFacility.title.lowercased())?")
                .font(.system(size: 14))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 12)

            Button {
                showReviewWizard = true
            } label: {
                Text("Update Review")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        MockMyReviewView()
    }
}
