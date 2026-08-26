import CryptoKit
import SwiftUI

/// One photo in a facility's gallery (Views/Photos/).
///
/// Photos reach the gallery from two directions, so the source is an enum
/// rather than a plain URL: already-published photos come back as remote URLs
/// (the same public `review-photos` Storage bucket ReviewService uploads to),
/// while photos the user just picked are still local `UIImage`s until submit.
struct FacilityPhoto: Identifiable {
    enum Source {
        /// Published photo, e.g. a `review-photos` public URL.
        case remote(URL)
        /// Just picked from the library or camera, not uploaded yet.
        case local(UIImage)
        /// Bundled placeholder (see `samples`).
        case asset(String)
    }

    let id: UUID
    let source: Source
    /// Groups photos from the same review for lightbox paging.
    var reviewId: UUID?
    /// Optional text shown under the photo in the lightbox (review notes or
    /// a per-photo caption when one exists).
    var caption: String?

    init(
        id: UUID = UUID(),
        source: Source,
        reviewId: UUID? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.source = source
        self.reviewId = reviewId
        self.caption = Self.normalizedCaption(caption)
    }

    init(
        id: UUID = UUID(),
        image: UIImage,
        reviewId: UUID? = nil,
        caption: String? = nil
    ) {
        self.init(id: id, source: .local(image), reviewId: reviewId, caption: caption)
    }

    private static func normalizedCaption(_ caption: String?) -> String? {
        guard let caption else { return nil }
        let trimmed = caption.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension FacilityPhoto {
    static let reviewThumbnails: [FacilityPhoto] = (0..<3).map { _ in
        FacilityPhoto(source: .asset("SamplePlacePhoto"))
    }

    /// Placeholder gallery so the Photos tab matches the mockup out of the box,
    /// mirroring `Place.samples`. The mosaic repeats a 10-photo cycle, so ten
    /// entries fill exactly one full pattern.
    static var samples: [FacilityPhoto] {
        (0..<10).map { _ in FacilityPhoto(source: .asset("SamplePlacePhoto")) }
    }
}

/// Backing store for one facility's gallery.
///
/// TODO(backend): there is no place/facility photo endpoint yet — only
/// `submit-accessibility-review`, which attaches photos to a *review*. So
/// `add(_:)` keeps new photos in memory and the gallery seeds from `samples`.
/// Once a gallery endpoint exists, `load()` should fetch remote URLs and
/// `add(_:)` should upload JPEGs to the `review-photos` bucket the way
/// `ReviewService.uploadPhotos` does, then swap the local entries for remote ones.
@MainActor
final class FacilityPhotoStore: ObservableObject {
    @Published private(set) var photos: [FacilityPhoto]

    init(photos: [FacilityPhoto] = []) {
        self.photos = photos
    }

    /// Newest first, so photos the user just added land in the hero slot.
    func add(_ newPhotos: [FacilityPhoto]) {
        guard !newPhotos.isEmpty else { return }
        photos.insert(contentsOf: newPhotos, at: 0)
    }
}

extension UUID {
    /// A deterministic id for a stable string key (a photo's URL).
    ///
    /// `FacilityPhoto` is rebuilt from scratch on every body evaluation, so a
    /// random `UUID()` gave the SAME photo a new identity on every render.
    /// SwiftUI then tore down and recreated every tile button in the mosaic —
    /// repeatedly, as each image finished loading — and a tap arriving during
    /// one of those rebuilds was delivered to the wrong view, opening the
    /// lightbox instead of the Add Photos menu.
    static func stable(from key: String) -> UUID {
        let digest = [UInt8](Insecure.MD5.hash(data: Data(key.utf8)))
        return UUID(uuid: (
            digest[0], digest[1], digest[2], digest[3],
            digest[4], digest[5], digest[6], digest[7],
            digest[8], digest[9], digest[10], digest[11],
            digest[12], digest[13], digest[14], digest[15]
        ))
    }
}
