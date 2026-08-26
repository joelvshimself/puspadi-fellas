import SwiftUI
import UIKit

/// Pinch / double-tap zoom and pan for a single photo, backed by UIScrollView.
struct ZoomablePhotoContainer: UIViewRepresentable {
    let image: UIImage
    @Binding var isZoomed: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(isZoomed: $isZoomed)
    }

    func makeUIView(context: Context) -> ZoomScrollView {
        let scrollView = ZoomScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        scrollView.addSubview(imageView)

        context.coordinator.scrollView = scrollView
        context.coordinator.imageView = imageView
        context.coordinator.currentImage = image

        scrollView.onBoundsChange = { [weak coordinator = context.coordinator] bounds in
            guard let coordinator, let scrollView = coordinator.scrollView else { return }
            let sizeChanged = abs(bounds.width - coordinator.lastLayoutSize.width) > 0.5
                || abs(bounds.height - coordinator.lastLayoutSize.height) > 0.5
            guard sizeChanged else { return }
            // First real size: fit the image. Later size changes (rotation):
            // reset zoom so the fit math stays correct.
            coordinator.layoutImage(in: scrollView, resetZoom: true)
        }

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: ZoomScrollView, context: Context) {
        let coordinator = context.coordinator
        guard coordinator.currentImage !== image else { return }

        coordinator.imageView?.image = image
        coordinator.currentImage = image
        coordinator.layoutImage(in: scrollView, resetZoom: true)
    }

    final class ZoomScrollView: UIScrollView {
        var onBoundsChange: ((CGSize) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            onBoundsChange?(bounds.size)
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        @Binding var isZoomed: Bool
        weak var scrollView: ZoomScrollView?
        weak var imageView: UIImageView?
        var currentImage: UIImage?
        var lastLayoutSize: CGSize = .zero

        init(isZoomed: Binding<Bool>) {
            _isZoomed = isZoomed
        }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            centerImage(in: scrollView)
            isZoomed = scrollView.zoomScale > scrollView.minimumZoomScale + 0.01
        }

        func scrollViewDidEndZooming(
            _ scrollView: UIScrollView,
            with view: UIView?,
            atScale scale: CGFloat
        ) {
            isZoomed = scale > scrollView.minimumZoomScale + 0.01
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            guard let imageView else { return }
            let point = recognizer.location(in: imageView)
            let targetScale = min(scrollView.maximumZoomScale, 2)
            let zoomRect = zoomRect(for: point, in: scrollView, scale: targetScale)
            scrollView.zoom(to: zoomRect, animated: true)
        }

        func layoutImage(in scrollView: UIScrollView, resetZoom: Bool) {
            guard let imageView, let image = imageView.image else { return }

            let bounds = scrollView.bounds
            guard bounds.width > 0, bounds.height > 0 else { return }

            lastLayoutSize = bounds.size

            let widthScale = bounds.width / image.size.width
            let heightScale = bounds.height / image.size.height
            let fitScale = min(widthScale, heightScale)
            let fittedSize = CGSize(
                width: floor(image.size.width * fitScale),
                height: floor(image.size.height * fitScale)
            )

            if resetZoom, scrollView.zoomScale > scrollView.minimumZoomScale + 0.01 {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: false)
            }

            imageView.frame = CGRect(origin: .zero, size: fittedSize)
            scrollView.contentSize = fittedSize
            centerImage(in: scrollView)
            if resetZoom {
                isZoomed = false
            }
        }

        private func centerImage(in scrollView: UIScrollView) {
            guard let imageView else { return }

            let boundsSize = scrollView.bounds.size
            var frameToCenter = imageView.frame

            if frameToCenter.size.width < boundsSize.width {
                frameToCenter.origin.x = (boundsSize.width - frameToCenter.size.width) / 2
            } else {
                frameToCenter.origin.x = 0
            }

            if frameToCenter.size.height < boundsSize.height {
                frameToCenter.origin.y = (boundsSize.height - frameToCenter.size.height) / 2
            } else {
                frameToCenter.origin.y = 0
            }

            imageView.frame = frameToCenter
        }

        private func zoomRect(for point: CGPoint, in scrollView: UIScrollView, scale: CGFloat) -> CGRect {
            let size = CGSize(
                width: scrollView.bounds.width / scale,
                height: scrollView.bounds.height / scale
            )
            let origin = CGPoint(
                x: point.x - size.width / 2,
                y: point.y - size.height / 2
            )
            return CGRect(origin: origin, size: size)
        }
    }
}
