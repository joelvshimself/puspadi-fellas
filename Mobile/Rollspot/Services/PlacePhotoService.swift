import Foundation
import Shared

struct PlacePhoto: Identifiable, Hashable, Decodable {
    let id: UUID
    let url: String
    let source: String
    let credit: String?
    let sortOrder: Int

    var imageURL: URL? { URL(string: url) }
    var requiresCredit: Bool { credit?.isEmpty == false }
}

extension PlacePhoto {
    /// Venue photos are fetched by the shared `PlaceDetailModel`; this only adapts one.
    init(shared photo: Shared.PlacePhoto) {
        self.id = UUID(uuidString: photo.id) ?? .stable(from: photo.id)
        self.url = photo.url
        self.source = photo.source
        self.credit = photo.credit
        self.sortOrder = Int(photo.sortOrder)
    }
}
