import Foundation
import Shared

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

extension ReviewPhoto {
    init(shared photo: Shared.ReviewPhoto) {
        self.init(url: photo.url, facility: photo.facility, label: photo.label, caption: photo.caption)
    }
}
