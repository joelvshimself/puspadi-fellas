import SwiftUI

struct SavedView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var savedPlacesService = SavedPlacesService.shared

    private var savedPlaces: [Place] {
        SavedPlaceSnapshotStore.savedPlaces(from: savedPlacesService.savedPlaceIds)
    }

    var body: some View {
        Group {
            if savedPlaces.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 48, weight: .light))
                        .foregroundStyle(.secondary)
                    Text("No Saved Places")
                        .font(.headline)
                    Text("Bookmark places to easily view them here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(savedPlaces) { place in
                    NavigationLink {
                        MockPlaceDetailView(place: place)
                            .enableSwipeBack()
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                                Image(systemName: "building.2.fill")
                                    .font(.system(size: 22))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 52, height: 52)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(place.name)
                                    .font(.body.weight(.semibold))
                                Text(place.address.isEmpty ? place.category : place.address)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Saved".localized)
        .navigationBarTitleDisplayMode(.inline)
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
        // The list renders from local snapshots, so it is already on screen
        // before this runs — this only reconciles with the server.
        .task {
            await savedPlacesService.fetchSavedPlaceIds()
        }
    }
}

#Preview {
    NavigationStack {
        SavedView()
    }
}
