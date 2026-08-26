import CoreLocation
import UIKit

/// Two-tier cache for place imagery.
///
/// Memory holds the decoded full-size image, so returning to a place is
/// instant. That matters most when Mapillary has no coverage: PlaceImageView
/// then falls back to a Look Around or map snapshot, and regenerating one of
/// those on every visit is the slowest thing on the detail page.
///
/// Disk holds a small thumbnail. It decodes fast enough to paint immediately,
/// so a first visit shows something real while the full image is still
/// arriving, instead of an empty box with a spinner.
///
/// Keyed by rounded coordinate (the same key PlaceCacheStore uses), not by
/// `place.id` — that is a fresh UUID per search result and would never hit.
@MainActor
final class ImageStore {
    static let shared = ImageStore()

    private let memory = NSCache<NSString, UIImage>()
    private let directory: URL
    private let thumbnailWidth: CGFloat = 48

    private init() {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("place-thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        memory.countLimit = 120
    }

    static func key(for coordinate: CLLocationCoordinate2D) -> String {
        PlaceCacheStore.key(lat: coordinate.latitude, lng: coordinate.longitude)
    }

    /// Full-size, already decoded. A hit means no network and no snapshot work.
    func image(for key: String) -> UIImage? {
        memory.object(forKey: key as NSString)
    }

    /// Low-quality stand-in to show while the full image loads.
    func thumbnail(for key: String) -> UIImage? {
        guard let data = try? Data(contentsOf: fileURL(key)) else { return nil }
        return UIImage(data: data)
    }

    func store(_ image: UIImage, for key: String) {
        memory.setObject(image, forKey: key as NSString)
        writeThumbnail(image, for: key)
    }

    private func writeThumbnail(_ image: UIImage, for key: String) {
        guard image.size.width > 0 else { return }
        let scale = thumbnailWidth / image.size.width
        let size = CGSize(width: thumbnailWidth, height: max(1, image.size.height * scale))
        let small = UIGraphicsImageRenderer(size: size).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        guard let data = small.jpegData(compressionQuality: 0.5) else { return }
        try? data.write(to: fileURL(key), options: .atomic)
    }

    private func fileURL(_ key: String) -> URL {
        let safe = key.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safe).jpg")
    }
}
