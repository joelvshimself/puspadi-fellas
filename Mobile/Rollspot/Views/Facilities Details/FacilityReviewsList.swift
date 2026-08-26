import SwiftUI

/// One review card (Figma "Reviewed"): avatar + name + role, date on the
/// trailing edge, a hairline under the header, then body text, the
/// "What Provided:" line, and a photo strip.
struct FacilityReviewRow: View {
    let review: PlaceFacilityReview
    var onSelectPhoto: (FacilityPhoto) -> Void = { _ in }

    private var photos: [FacilityPhoto] {
        review.photoURLs.enumerated().compactMap { index, urlString in
            guard let remote = URL(string: urlString) else { return nil }
            return FacilityPhoto(
                source: .remote(remote),
                reviewId: review.reviewId,
                caption: review.caption(forPhotoAt: index)
            )
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM yyyy"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                avatar

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(review.bylineName ?? "Community".localized)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        // A handle like "Tidal Frangipani" reads as a real name
                        // unless something says otherwise, and a reader
                        // weighing a stranger's account of a ramp deserves to
                        // know which they are looking at.
                        if review.reviewerIsPseudonym {
                            Image(systemName: "theatermasks")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Pseudonym".localized)
                        }
                    }
                    if let role = review.reviewerRole {
                        Text(role.localized)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                    if let badge = review.provenance.badgeLabel {
                        if let source = review.sourceURL {
                            // Tappable: the quote is somebody else's writing,
                            // and a citation nobody can follow is not really a
                            // citation.
                            Link(destination: source) {
                                HStack(spacing: 4) {
                                    provenanceBadge(badge)
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            provenanceBadge(badge)
                        }
                    }
                }

                Spacer()

                Text(Self.dateFormatter.string(from: review.createdAt))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            Divider()

            // Only when there is something to show. Most reviews answer just
            // the structured questions, and this used to render the fabricated
            // string "Community review" for every one of them — the same
            // sentence under every card, saying nothing. What those reviews
            // actually contribute is the "What Provided:" line below.
            if review.hasBodyText {
                Text(review.bodyText)
                    .font(.system(size: 15))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !review.providedList.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    Text("What Provided:".localized)
                        .font(.system(size: 15, weight: .semibold))
                    Text(review.providedList.lowercased().capitalized)
                        .font(.system(size: 15))
                }
            }

            if !photos.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photos) { photo in
                            Button { onSelectPhoto(photo) } label: {
                                ZStack(alignment: .bottom) {
                                    FacilityPhotoImage(photo: photo, cornerRadius: 10)
                                    if let caption = photo.caption {
                                        PhotoCaptionOverlay(caption: caption)
                                    }
                                }
                                .frame(width: 88, height: 88)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    /// Marks a card whose content did not come from a person using the app.
    /// Deliberately plain rather than decorative — this is a caveat, not a
    /// feature.
    private func provenanceBadge(_ text: String) -> some View {
        Text(text.localized)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.systemGray6))
            )
            .padding(.top, 2)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = review.reviewerAvatarURL {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().aspectRatio(contentMode: .fill)
                } else {
                    avatarPlaceholder
                }
            }
            .frame(width: 38, height: 38)
            .clipShape(Circle())
        } else {
            avatarPlaceholder
                .frame(width: 38, height: 38)
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color(.systemGray5))
            .overlay {
                Image(systemName: "person.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(.secondary)
            }
    }
}

/// Chips over the list (Figma "Reviewed"): ALL, 📷 WITH PHOTOS, then one chip
/// per confirmed tag with its review count — "RAMP (3)".
private enum ReviewFilter: Hashable, Identifiable {
    case all
    case withPhotos
    case tag(String)

    var id: String {
        switch self {
        case .all: "all"
        case .withPhotos: "withPhotos"
        case .tag(let tag): "tag-\(tag)"
        }
    }
}

struct FacilityReviewsList: View {
    let reviews: [PlaceFacilityReview]

    @State private var selectedFilter: ReviewFilter = .all
    @State private var lightbox: LightboxSelection?

    private struct LightboxSelection: Identifiable {
        let id = UUID()
        let photos: [FacilityPhoto]
        let initialID: UUID
    }

    /// Distinct tags across the reviews, most common first, with counts.
    private var tagCounts: [(tag: String, count: Int)] {
        var counts: [String: Int] = [:]
        for review in reviews {
            for tag in Set(review.providedTags) where tag != "NOT AVAILABLE" {
                counts[tag, default: 0] += 1
            }
        }
        return counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .map { (tag: $0.key, count: $0.value) }
    }

    private var filters: [ReviewFilter] {
        [.all, .withPhotos] + tagCounts.map { .tag($0.tag) }
    }

    private var filtered: [PlaceFacilityReview] {
        switch selectedFilter {
        case .all: reviews
        case .withPhotos: reviews.filter { !$0.photoURLs.isEmpty }
        case .tag(let tag): reviews.filter { $0.providedTags.contains(tag) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(filters) { filter in
                        filterChip(filter)
                    }
                }
            }
            .scrollClipDisabled()

            if filtered.isEmpty {
                Text("No reviews match this filter".localized)
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { index, review in
                        if index > 0 { Divider() }
                        FacilityReviewRow(review: review) { photo in
                            let siblings = review.photoURLs.enumerated().compactMap { index, urlString -> FacilityPhoto? in
                                guard let remote = URL(string: urlString) else { return nil }
                                return FacilityPhoto(
                                    source: .remote(remote),
                                    reviewId: review.reviewId,
                                    caption: review.caption(forPhotoAt: index)
                                )
                            }
                            lightbox = LightboxSelection(photos: siblings, initialID: photo.id)
                        }
                        .padding(.vertical, 14)
                    }
                }
            }
        }
        .fullScreenCover(item: $lightbox) { selection in
            FacilityPhotoDetailView(photos: selection.photos, initialID: selection.initialID)
        }
    }

    private func chipLabel(_ filter: ReviewFilter) -> String {
        switch filter {
        case .all: "ALL".localized
        case .withPhotos: "WITH PHOTOS".localized
        case .tag(let tag):
            if let count = tagCounts.first(where: { $0.tag == tag })?.count {
                "\(tag.localized) (\(count))"
            } else {
                tag.localized
            }
        }
    }

    private func filterChip(_ filter: ReviewFilter) -> some View {
        let isSelected = selectedFilter == filter
        return Button { selectedFilter = filter } label: {
            HStack(spacing: 6) {
                if filter == .withPhotos {
                    Image(systemName: "camera").font(.caption)
                }
                Text(chipLabel(filter))
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(isSelected ? Color.accentColor : Color.mockSectionBackground))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    FacilityReviewsList(reviews: [
        PlaceFacilityReview(
            id: UUID(),
            reviewId: UUID(),
            kind: .entrance,
            createdAt: .now,
            bodyText: "The entrance is quite hard to find. When I went there, there's a lot of stairs and it is very hard too see the signage and need to ask the security.",
            providedTags: ["RAMP", "HANDRAIL", "AUTOMATIC DOORS"],
            photoURLs: [],
            photoCaptions: [],
            reviewerName: "Aarief M.",
            reviewerRole: "Wheelchair User"
        )
    ])
    .padding()
    .background(Color.white)
}
