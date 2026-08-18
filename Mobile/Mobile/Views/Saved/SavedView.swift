import SwiftUI

struct SavedView: View {
    @StateObject private var savedPlacesService = SavedPlacesService.shared

    private var savedPlaces: [Place] {
        Place.baliMalls.filter { savedPlacesService.isSaved(placeId: $0.name) || savedPlacesService.isSaved(placeId: $0.id.uuidString) }
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
            }
        }
        .navigationTitle("Saved")
        .navigationBarTitleDisplayMode(.inline)
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
