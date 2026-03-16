import SwiftUI

private struct ZoomGestureModifier: ViewModifier {
    let uiImage: UIImage?
    let clipShape: AnyShape?

    @ObservedObject private var zoomOverlay = ZoomOverlayManager.shared

    func body(content: Content) -> some View {
        content
            .opacity(isShowingThisImage ? 0 : 1)
            .overlay(Group {
                if let uiImage {
                    ZoomGestureView(uiImage: uiImage, clipShape: clipShape)
                }
            })
    }

    private var isShowingThisImage: Bool {
        guard let uiImage, zoomOverlay.isVisible else { return false }
        return zoomOverlay.image === uiImage
    }
}

extension View {
    func zoomGestures(uiImage: UIImage?, clipShape: AnyShape?) -> some View {
        modifier(ZoomGestureModifier(uiImage: uiImage, clipShape: clipShape))
    }
}

/// Transparent UIView overlay on the card that drives ZoomOverlayManager
/// during the originating gesture phase (before the overlay takes over).
struct ZoomGestureView: UIViewRepresentable {
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
        private var manager: ZoomOverlayManager { .shared }

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

        private func presentIfNeeded(view: UIView) {
            if !manager.isVisible {
                manager.present(image: uiImage, from: screenSpaceFrame(for: view), clipShape: clipShape)
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
                let clampedScale = rubberBand(rawScale, min: ZoomOverlayConstants.minScale, max: ZoomOverlayConstants.maxScale, coefficient: ZoomOverlayConstants.scaleRubberBandCoefficient)
                let effectiveDScale = clampedScale / manager.scale
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                manager.offset.width += (centroid.x - imageCenterX) * (1 - effectiveDScale)
                manager.offset.height += (centroid.y - imageCenterY) * (1 - effectiveDScale)
                manager.scale = clampedScale
            case .ended:
                let screenSize = view.window?.screen.bounds.size ?? UIScreen.main.bounds.size
                manager.commitPinchGesture(screenSize: screenSize)
            case .cancelled, .failed:
                manager.dismiss()
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended,
                  let view = recognizer.view,
                  let screenSize = view.window?.screen.bounds.size else { return }
            manager.presentCentered(image: uiImage, from: screenSpaceFrame(for: view), clipShape: clipShape, screenSize: screenSize)
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
                var view: UIView? = gestureRecognizer.view?.superview
                while let v = view {
                    if let scrollView = v as? UIScrollView,
                       scrollView.isDecelerating || scrollView.isOutOfBounds {
                        return false
                    }
                    view = v.superview
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

