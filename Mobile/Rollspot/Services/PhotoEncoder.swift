import Shared
import UIKit

/// Turns any picked or captured image into an upload-ready JPEG, following the shared
/// `PhotoUpload` rules (Android: PhotoEncoding.kt). HEIC, PNG and huge camera photos all
/// come out upright, at most 2048 px (1024 for avatars), and under the backend's size limit.
enum PhotoEncoder {
    struct Encoded {
        /// The resized image, for thumbnails: keeps a 48 MP original out of memory.
        let image: UIImage
        let jpeg: Data
    }

    static func encode(_ image: UIImage, for upload: PhotoUpload = .review) -> Encoded? {
        // `size` is already in display orientation; `scale` turns points into pixels.
        let pixelWidth = Int32((image.size.width * image.scale).rounded())
        let pixelHeight = Int32((image.size.height * image.scale).rounded())
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }
        let target = upload.targetSize(width: pixelWidth, height: pixelHeight)
        let size = CGSize(width: Int(target.width), height: Int(target.height))

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        // Drawing applies the EXIF orientation, so the pixels come out upright.
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { context in
            // JPEG has no transparency: put see-through PNGs on white rather than black.
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        let bytes = upload.encodeWithinLimit { quality in
            resized.jpegData(compressionQuality: CGFloat(quality.intValue) / 100)?.asKotlinByteArray()
        }
        guard let bytes else { return nil }
        return Encoded(image: resized, jpeg: bytes.asData())
    }
}
