import CoreLocation
import SwiftUI

/// "Your Review" screen — reached from place detail's submitted banner or from
/// a profile review card's Update Review button.
struct MockMyReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showReviewWizard = false

    private let place: Place
    private let userName: String
    private let avatarURL: URL?
    private let userRole: String
    private let cardDateLabel: String
    private let reviewedDateLabel: String
    private let notesText: String
    private let providedTags: [String]
    private let photoURLs: [URL]
    private let isPreview: Bool

    /// SwiftUI preview — mock Park23 Mall demo data.
    init() {
        let mockPlace = Place.fromSearchResult(
            name: MockData.placeName,
            category: "Mall",
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0)
        )
        self.place = mockPlace
        self.userName = "Aarief M."
        self.avatarURL = nil
        self.userRole = "Wheelchair User".localized
        self.cardDateLabel = "Jan 2025"
        self.reviewedDateLabel = MockData.review.reviewedDateLabel
        self.notesText = MockData.review.notes
        self.providedTags = ["Ramp", "Handrail", "Automatic Doors", "Manual Doors"]
        self.photoURLs = []
        self.isPreview = true
    }

    /// Real user review for one place (profile or place-detail entry).
    init(
        place: Place,
        reviewId: UUID,
        userName: String,
        avatarURL: URL?,
        userRole: String,
        dateLabel: String,
        notes: String,
        providedTags: [String],
        photoURLs: [URL]
    ) {
        self.place = place
        self.userName = userName
        self.avatarURL = avatarURL
        self.userRole = userRole
        self.cardDateLabel = dateLabel
        self.reviewedDateLabel = dateLabel
        self.notesText = notes
        self.providedTags = providedTags
        self.photoURLs = photoURLs
        self.isPreview = false
    }

    var body: some View {
        VStack(spacing: 0) {
            PhotoFlowHeader(title: "Your Review", onBack: { dismiss() })
                .background(Color(.systemBackground))

            ScrollView {
                VStack(spacing: 0) {
                    placeInfoSection
                        .background(StretchyTopBackground(color: Color(.systemBackground)))
                    reviewContentSection
                }
            }
            .coordinateSpace(name: "reviewScroll")
            .background(Color.mockSectionBackground)
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showReviewWizard) {
            ContributeReviewFlowView(
                place: place,
                initialScreenIndex: 0,
                ignoreDraftRestore: true,
                onFinished: { showReviewWizard = false }
            )
        }
    }

    // MARK: Place info

    private var placeInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(place.name)
                .font(.system(size: 22, weight: .bold))
            Text("Reviewed at \(reviewedDateLabel)")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }

    // MARK: Review card + footer

    private var reviewContentSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            reviewCard
            updatePromptSection
        }
        .padding(.horizontal, 22)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var reviewCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                reviewAvatar

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(userName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(cardDateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !userRole.isEmpty {
                        Text(userRole)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            formattedNotesText(notesText)
                .fixedSize(horizontal: false, vertical: true)

            if !providedTags.isEmpty {
                (
                    Text("What Provided:".localized + " ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    + Text(providedTags.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            if isPreview {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(MockData.photos) { photo in
                            MockPhotoTile(photo: photo)
                                .frame(width: 96, height: 96)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            } else if !photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photoURLs.indices, id: \.self) { idx in
                            AsyncImage(url: photoURLs[idx]) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Color(.secondarySystemBackground).overlay { ProgressView() }
                                }
                            }
                            .frame(width: 96, height: 96)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
    }

    private var updatePromptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Any changes in the entrance?".localized)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)

            Button(action: startUpdateReview) {
                Text("Update Review".localized)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AuthPalette.brandBlue)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        Capsule()
                            .fill(Color(uiColor: .systemBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(AuthPalette.brandBlue.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private func startUpdateReview() {
        UnfinishedReviewStore.clear(for: place)
        showReviewWizard = true
    }

    @ViewBuilder
    private var reviewAvatar: some View {
        if let url = avatarURL {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                default:
                    placeholderReviewAvatar
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
        } else {
            placeholderReviewAvatar
        }
    }

    private var placeholderReviewAvatar: some View {
        Image("Profile Avatar")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(width: 40, height: 40)
            .clipShape(Circle())
    }

    private func formattedNotesText(_ notes: String) -> Text {
        let lines = notes.components(separatedBy: "\n")
        guard !lines.isEmpty else {
            return Text(notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        var combined = Text("")
        for (index, line) in lines.enumerated() {
            if index > 0 {
                combined = combined + Text("\n")
            }
            combined = combined + formattedNoteLine(line)
        }
        return combined
    }

    private func formattedNoteLine(_ line: String) -> Text {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "[",
              let closeBracket = trimmed.firstIndex(of: "]")
        else {
            return Text(trimmed)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }

        let inner = trimmed[trimmed.index(after: trimmed.startIndex)..<closeBracket]
        let remainderStart = trimmed.index(after: closeBracket)
        let remainder = remainderStart < trimmed.endIndex
            ? String(trimmed[remainderStart...]).trimmingCharacters(in: .whitespaces)
            : ""

        let label: String
        if let colon = inner.lastIndex(of: ":") {
            label = String(inner[inner.index(after: colon)...])
        } else {
            label = String(inner)
        }

        let labelText = Text(label)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.secondary)

        guard !remainder.isEmpty else { return labelText }

        return labelText
            + Text(" \(remainder)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
    }
}

/// A background that grows upward to fill top pull-to-refresh overscroll.
private struct StretchyTopBackground: View {
    let color: Color

    var body: some View {
        GeometryReader { geo in
            let minY = geo.frame(in: .named("reviewScroll")).minY
            let stretch = max(0, minY)
            color
                .frame(height: geo.size.height + stretch)
                .offset(y: -stretch)
        }
    }
}

#Preview {
    NavigationStack {
        MockMyReviewView()
    }
}
