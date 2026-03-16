import SwiftUI

/// Transparent UIView overlay that drives ZoomOverlayState
/// during the originating gesture phase (before the overlay takes over).
struct ZoomOverlayInitiatingGestureView: UIViewRepresentable {
    let uiImage: UIImage
    let clipShape: AnyShape?

    func makeCoordinator() -> Coordinator {
        Coordinator(uiImage: uiImage, clipShape: clipShape)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let coordinator = context.coordinator
        view.addGestureRecognizer(coordinator.pinchRecognizer)
        view.addGestureRecognizer(coordinator.panRecognizer)
        view.addGestureRecognizer(coordinator.tapRecognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let uiImage: UIImage
        private let clipShape: AnyShape?
        private var manager: ZoomOverlayState { .shared }

        // Cumulative scale at pinch start, so rubber-banding sees total overshoot.
        private var scaleAtPinchBegan: CGFloat = 1

        lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        lazy var panRecognizer: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            return pan
        }()

        init(uiImage: UIImage, clipShape: AnyShape?) {
            self.uiImage = uiImage
            self.clipShape = clipShape
            super.init()
            pinchRecognizer.delegate = self
            panRecognizer.delegate = self
            tapRecognizer.delegate = self
            // Tap only fires if pinch hasn't recognized.
            tapRecognizer.require(toFail: pinchRecognizer)
        }

        private func screenSpaceFrame(for view: UIView) -> CGRect {
            view.convert(view.bounds, to: nil)
        }

        private func screenSize(for view: UIView) -> CGSize {
            view.window?.screen.bounds.size ?? UIScreen.main.bounds.size
        }

        private func presentIfNeeded(view: UIView) {
            if !manager.isVisible {
                manager.initiate(with: uiImage, from: screenSpaceFrame(for: view), screenSize: screenSize(for: view), clippingTo: clipShape)
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                presentIfNeeded(view: view)
                scaleAtPinchBegan = manager.scale
            case .changed:
                presentIfNeeded(view: view)
                // recognizer.scale is cumulative since .began.
                let rawScale = scaleAtPinchBegan * recognizer.scale
                let clampedScale = rubberBand(rawScale, min: ZoomOverlayConstants.minRetainedZoomScale, max: ZoomOverlayConstants.maxNonRubberBandingZoomScale, coefficient: ZoomOverlayConstants.scaleRubberBandCoefficient)
                let effectiveDScale = clampedScale / manager.scale
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                manager.offset.width += (centroid.x - imageCenterX) * (1 - effectiveDScale)
                manager.offset.height += (centroid.y - imageCenterY) * (1 - effectiveDScale)
                manager.scale = clampedScale
            case .ended:
                manager.maybeCommitInitiatingGesture()
            case .cancelled, .failed:
                manager.dismiss()
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }
            let frame = screenSpaceFrame(for: view)
            let size = screenSize(for: view)
            manager.initiate(with: uiImage, from: frame, screenSize: size, clippingTo: clipShape)
            let targetOffset = CGSize(width: size.width / 2 - frame.midX, height: size.height / 2 - frame.midY)
            withAnimation(ZoomOverlayConstants.presentCenteredAnimation) {
                manager.scale = ZoomOverlayConstants.fullOpacityReachedAtScaleFactor
                manager.offset = targetOffset
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                let t = recognizer.translation(in: recognizer.view)
                manager.offset.width += t.x
                manager.offset.height += t.y
                recognizer.setTranslation(.zero, in: recognizer.view)
            default:
                break
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // The pan recognizer only exists to track finger drift during a pinch.
            // Don't let it recognize on its own.
            if gestureRecognizer === panRecognizer {
                return pinchRecognizer.state == .began || pinchRecognizer.state == .changed
            }

            // Don't open the preview via tap if the user is touching down to arrest a
            // scrolling scroll view. Check whether any scroll view in the hierarchy is
            // currently decelerating.
            if gestureRecognizer === tapRecognizer {
                if let scrollView = gestureRecognizer.view?.firstScrollViewAncestor {
                    return !scrollView.isDecelerating && !scrollView.isOutOfBounds
                }
            }
            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // While pinching, block any pan gestures not on our own view
            // (scroll views, sheet dismiss, etc.).
            if gestureRecognizer === pinchRecognizer,
               other is UIPanGestureRecognizer,
               other !== panRecognizer {
                return false
            }
            return true
        }
    }
}
private extension UIView {
    var firstScrollViewAncestor: UIScrollView? {
        var view = superview
        while let v = view {
            if let scrollView = v as? UIScrollView { return scrollView }
            view = v.superview
        }
        return nil
    }
}

private extension UIScrollView {
    var isOutOfBounds: Bool {
        let inset = adjustedContentInset
        let offset = contentOffset
        let minX = -inset.left
        let minY = -inset.top
        let maxX = max(minX, contentSize.width - bounds.width + inset.right)
        let maxY = max(minY, contentSize.height - bounds.height + inset.bottom)
        return offset.x < minX || offset.x > maxX || offset.y < minY || offset.y > maxY
    }
}

