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

    init(id: UUID = UUID(), source: Source, reviewId: UUID? = nil) {
        self.id = id
        self.source = source
        self.reviewId = reviewId
    }

    init(id: UUID = UUID(), image: UIImage, reviewId: UUID? = nil) {
        self.init(id: id, source: .local(image), reviewId: reviewId)
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
