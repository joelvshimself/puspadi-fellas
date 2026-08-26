import Foundation

/// One community review photo returned by `place-review-photos`.
struct ReviewPhoto: Decodable, Identifiable, Hashable {
    let url: String
    let facility: String
    let label: String
    let caption: String?

    var id: String { url }

    var imageURL: URL? { URL(string: url) }

    var trimmedCaption: String? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct PlaceReviewPhotosResponse: Decodable {
    let status: String
    let placeId: String
    let photos: [ReviewPhoto]
}
