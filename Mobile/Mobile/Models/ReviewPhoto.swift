import Foundation

/// One community review photo returned by `place-review-photos`.
struct ReviewPhoto: Decodable, Identifiable, Hashable {
    let url: String
    let facility: String
    let label: String

    var id: String { url }

    var imageURL: URL? { URL(string: url) }
}

struct PlaceReviewPhotosResponse: Decodable {
    let status: String
    let placeId: String
    let photos: [ReviewPhoto]
}
