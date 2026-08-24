import CoreLocation
import SwiftUI

struct ProfileReviewItem: Identifiable, Equatable, Hashable {
    let id: UUID
    var userName: String
    var userAvatarURL: URL?
    var userRole: String = ""
    var dateLabel: String
    var placeId: String
    var placeName: String
    var notes: String
    var providedTags: [String]
    var photoURLs: [URL]
}

struct ProfileReviewsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @EnvironmentObject private var auth: AuthSessionStore

    var displayName: String
    var avatarURL: URL?
    var mobilityLabel: String = ""

    @State private var reviews: [ProfileReviewItem] = []
    @State private var reviewToDelete: ProfileReviewItem? = nil
    @State private var reviewToOpen: ProfileReviewItem? = nil
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var showSuccessToast = false
    @State private var deleteError: String?

    var body: some View {
        ZStack(alignment: .top) {
            Color.mockSectionBackground.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("\("All reviews".localized) (\(reviews.count))")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 20)
                        .padding(.top, 12)

                    if reviews.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary)
                            Text("No reviews yet".localized)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(reviews) { review in
                                reviewCard(review)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .padding(.bottom, 40)
            }

            if showSuccessToast {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.green)

                    Text("Review successfully removed".localized)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.primary)

                    Spacer()

                    Button {
                        withAnimation { showSuccessToast = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.green.opacity(0.12))
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.green.opacity(0.3), lineWidth: 1)
                )
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .task(id: auth.userId) {
            await loadReviewsFromSupabase()
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            deleteConfirmationSheet
                .presentationDetents([.height(240)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(item: $reviewToOpen) { review in
            MockPlaceDetailView(place: place(for: review))
                .enableSwipeBack()
        }
    }

    private func loadReviewsFromSupabase() async {
        guard auth.userId != nil else {
            await MainActor.run { reviews = [] }
            return
        }
        do {
            let response = try await ReviewService.shared.fetchMyReviews()
            let resolvedName = response.userName?.isEmpty == false ? response.userName! : (displayName.isEmpty ? "You" : displayName)
            let resolvedAvatar = response.profileImageUrl.flatMap(URL.init(string:)) ?? avatarURL
            let resolvedRole = response.userRole?.localized ?? mobilityLabel
            let items = response.reviews.map { row in
                let resolved = SavedPlaceSnapshotStore.place(for: row.placeId)
                return ProfileReviewItem(
                    id: row.id,
                    userName: resolvedName,
                    userAvatarURL: resolvedAvatar,
                    userRole: resolvedRole,
                    dateLabel: ReviewService.profileDateLabel(row.createdAt),
                    placeId: row.placeId,
                    placeName: resolved?.name ?? row.placeName,
                    notes: row.reviewText,
                    providedTags: row.providedFeatures,
                    photoURLs: row.photoURLs
                )
            }
            await MainActor.run { self.reviews = items }
        } catch {
            print("ProfileReviewsView: Failed to fetch reviews from Supabase: \(error)")
        }
    }

    /// Rebuilds the Place for navigation using the review's canonical
    /// `loc_lat_lng` place id (same key as place detail + saves).
    private func place(for review: ProfileReviewItem) -> Place {
        if let snap = SavedPlaceSnapshotStore.place(for: review.placeId) {
            return snap
        }
        if let coordinate = Self.coordinate(fromCanonicalPlaceId: review.placeId) {
            return Place.fromSearchResult(
                name: review.placeName == review.placeId ? "Place".localized : review.placeName,
                category: "Place",
                coordinate: coordinate
            )
        }
        return Place.fromSearchResult(
            name: review.placeName,
            category: "Place",
            coordinate: .init(latitude: 0, longitude: 0)
        )
    }

    /// Parses `loc_-8.72000_115.20000` into a coordinate.
    private static func coordinate(fromCanonicalPlaceId placeId: String) -> CLLocationCoordinate2D? {
        guard placeId.hasPrefix("loc_") else { return nil }
        let parts = placeId.dropFirst(4).split(separator: "_")
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lng = Double(parts[1])
        else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    private func reviewCard(_ review: ProfileReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                reviewAvatar(review)

                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(review.userName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(review.dateLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if !review.userRole.isEmpty {
                        Text(review.userRole)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()

            formattedNotesText(review.notes)
                .fixedSize(horizontal: false, vertical: true)

            if !review.providedTags.isEmpty {
                (
                    Text("What Provided:".localized + " ")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    + Text(review.providedTags.joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                )
                .fixedSize(horizontal: false, vertical: true)
            }

            if !review.photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(review.photoURLs.indices, id: \.self) { idx in
                            AsyncImage(url: review.photoURLs[idx]) { phase in
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

            HStack(spacing: 12) {
                Button {
                    reviewToDelete = review
                    deleteError = nil
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.red.opacity(0.12))
                        )
                }

                Button {
                    reviewToOpen = review
                } label: {
                    Text("Update Review".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AuthPalette.brandBlue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            Capsule()
                                .fill(PhotoPalette.background1)
                        )
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .systemBackground))
                .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        )
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

    /// Turns `[entrance:lobby] It has stairs` into **lobby** It has stairs.
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

    @ViewBuilder
    private func reviewAvatar(_ review: ProfileReviewItem) -> some View {
        if let url = review.userAvatarURL {
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

    private var deleteConfirmationSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Delete Review?".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)

                Text("Your review will permanently removed. This action is irreversible.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            if let deleteError {
                Text(deleteError)
                    .font(.caption)
                    .foregroundStyle(AuthPalette.errorRed)
                    .padding(.horizontal, 20)
            }

            HStack(spacing: 12) {
                Button {
                    showDeleteConfirmation = false
                    reviewToDelete = nil
                    deleteError = nil
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
                .disabled(isDeleting)

                Button {
                    Task { await confirmDelete() }
                } label: {
                    Group {
                        if isDeleting {
                            ProgressView()
                        } else {
                            Text("Delete".localized)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.red)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(Color.red.opacity(0.15))
                    )
                }
                .disabled(isDeleting)
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func confirmDelete() async {
        guard let target = reviewToDelete else { return }
        isDeleting = true
        deleteError = nil
        defer { isDeleting = false }
        do {
            try await ReviewService.shared.deleteMyReview(id: target.id)
            await MainActor.run {
                withAnimation {
                    reviews.removeAll { $0.id == target.id }
                    showDeleteConfirmation = false
                    reviewToDelete = nil
                    showSuccessToast = true
                }
            }
        } catch {
            await MainActor.run {
                deleteError = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        ProfileReviewsView(displayName: "Aarief M.", avatarURL: nil)
            .environmentObject(LanguageManager.shared)
            .environmentObject(AuthSessionStore())
    }
}
