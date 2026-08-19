import SwiftUI

struct ProfileReviewItem: Identifiable, Equatable {
    let id: UUID
    var userName: String
    var userAvatar: String?
    var dateLabel: String
    var placeName: String
    var notes: String
    var providedTags: [String]
    var photoURLs: [URL]
}

struct ProfileReviewsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    
    @State private var reviews: [ProfileReviewItem] = []
    @State private var reviewToDelete: ProfileReviewItem? = nil
    @State private var reviewToUpdate: ProfileReviewItem? = nil
    @State private var showDeleteConfirmation = false
    @State private var showSuccessToast = false
    
    var body: some View {
        ZStack(alignment: .top) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
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
            
            // Top Toast Banner
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
                        withAnimation {
                            showSuccessToast = false
                        }
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
        .task {
            await loadReviewsFromSupabase()
        }
        .sheet(isPresented: $showDeleteConfirmation) {
            deleteConfirmationSheet
                .presentationDetents([.height(240)])
                .presentationCornerRadius(28)
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(item: $reviewToUpdate) { review in
            let place = SavedPlaceSnapshotStore.place(for: review.placeName)
                ?? Place.fromSearchResult(
                    name: review.placeName,
                    category: "Place",
                    coordinate: .init(latitude: 0, longitude: 0)
                )
            ContributeReviewFlowView(place: place) {
                reviewToUpdate = nil
            }
        }
    }

    private func loadReviewsFromSupabase() async {
        do {
            let dbRows = try await ReviewService.shared.fetchAllReviews()
            var items: [ProfileReviewItem] = []
            for row in dbRows {
                let placeName = SavedPlaceSnapshotStore.place(for: row.placeId)?.name ?? row.placeId
                var urls: [URL] = []
                if let elevator = row.elevatorPhotoUrls {
                    urls.append(contentsOf: elevator.compactMap { URL(string: $0) })
                }
                if let toilet = row.toiletPhotoUrls {
                    urls.append(contentsOf: toilet.compactMap { URL(string: $0) })
                }
                let item = ProfileReviewItem(
                    id: row.id,
                    userName: "Community Contributor",
                    userAvatar: nil,
                    dateLabel: String(row.createdAt.prefix(10)),
                    placeName: placeName,
                    notes: row.notes ?? "No review notes written.",
                    providedTags: ["Elevator", "Toilet", "Entrance"],
                    photoURLs: urls
                )
                items.append(item)
            }
            await MainActor.run {
                self.reviews = items
            }
        } catch {
            print("ProfileReviewsView: Failed to fetch reviews from Supabase: \(error)")
        }
    }
    
    private func reviewCard(_ review: ProfileReviewItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: User avatar, name, date, place
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 36, height: 36)
                    .foregroundStyle(.gray.opacity(0.6))
                    .clipShape(Circle())
                
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
                    
                    Text(review.placeName)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            
            // Notes
            Text(review.notes)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // What Provided
            if !review.providedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("What Provided:".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(review.providedTags.joined(separator: ", "))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }
            
            // Photos thumbnails
            if !review.photoURLs.isEmpty {
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
                        .frame(width: 80, height: 70)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
            }
            
            // Action footer
            HStack(spacing: 12) {
                // Delete button
                Button {
                    reviewToDelete = review
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.red.opacity(0.8))
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color.red.opacity(0.1))
                        )
                }
                
                // Update Review button
                Button {
                    reviewToUpdate = review
                } label: {
                    Text("Update Review".localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .fill(Color.accentColor.opacity(0.08))
                        )
                }
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var deleteConfirmationSheet: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Delete Review?".localized)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text("Your review will permanently removed. This action is irreversible.".localized)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            HStack(spacing: 12) {
                Button {
                    showDeleteConfirmation = false
                    reviewToDelete = nil
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
                    if let target = reviewToDelete {
                        withAnimation {
                            reviews.removeAll { $0.id == target.id }
                            showDeleteConfirmation = false
                            reviewToDelete = nil
                            showSuccessToast = true
                        }
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
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProfileReviewsView()
        .environmentObject(LanguageManager.shared)
}
