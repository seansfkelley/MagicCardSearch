import SwiftUI
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "ZoomOverlayInitiatingGestureView")

enum ZoomOverlayInitationGestures {
    case tapOnly, pinchOnly, tapAndPinch

    var allowsTap: Bool {
        switch self {
        case .tapOnly, .tapAndPinch: true
        case .pinchOnly: false
        }
    }

    var allowsPinch: Bool {
        switch self {
        case .pinchOnly, .tapAndPinch: true
        case .tapOnly: false
        }
    }
}

/// Transparent UIView overlay that drives ZoomOverlayState
/// during the originating gesture phase (before the overlay takes over).
struct ZoomOverlayInitiatingGestureView: UIViewRepresentable {
    let uiImage: UIImage
    let clipShape: AnyShape?
    let initiatingGestures: ZoomOverlayInitationGestures

    func makeCoordinator() -> Coordinator {
        Coordinator(uiImage: uiImage, clipShape: clipShape, initiatingGestures: initiatingGestures)
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

    // n.b. can't make this private and don't want to rename it, so can't pull it out to file scope
    // else it will collide with the other Coordinator and generally be vague.
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let uiImage: UIImage
        private let clipShape: AnyShape?
        private let initiatingGestures: ZoomOverlayInitationGestures
        private var state: ZoomOverlayState { .shared }

        fileprivate lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        fileprivate lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        fileprivate lazy var panRecognizer: UIPanGestureRecognizer = {
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan))
            pan.minimumNumberOfTouches = 2
            pan.maximumNumberOfTouches = 2
            return pan
        }()

        init(uiImage: UIImage, clipShape: AnyShape?, initiatingGestures: ZoomOverlayInitationGestures) {
            self.uiImage = uiImage
            self.clipShape = clipShape
            self.initiatingGestures = initiatingGestures
            super.init()
            pinchRecognizer.delegate = self
            tapRecognizer.delegate = self
            panRecognizer.delegate = self
            // Tap only fires if pinch hasn't recognized.
            tapRecognizer.require(toFail: pinchRecognizer)
        }

        private func screenSpaceFrame(for view: UIView) -> CGRect {
            view.convert(view.bounds, to: nil)
        }

        private func screenSize(for view: UIView) -> CGSize {
            view.window?.windowScene?.screen.bounds.size ?? .zero
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }

            switch recognizer.state {
            case .began:
                state.show(
                    image: uiImage,
                    in: screenSpaceFrame(for: view),
                    screenSize: screenSize(for: view),
                    clippingImageWith: clipShape,
                    with: .continuingGesture,
                )
            case .changed:
                state.applyScale(recognizer.scale, aroundCentroid: recognizer.location(in: nil))
            case .ended:
                state.initiatingGestureFinished()
            case .cancelled, .failed:
                state.dismiss()
            case .possible:
                break
            @unknown default:
                logger.warning("received unknown pinch gesture recognizer state=\(recognizer.state.rawValue)")
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            guard recognizer.state == .ended, let view = recognizer.view else { return }

            let frame = screenSpaceFrame(for: view)
            let size = screenSize(for: view)
            let targetOffset = CGSize(width: size.width / 2 - frame.midX, height: size.height / 2 - frame.midY)

            state.show(
                image: uiImage,
                in: frame,
                screenSize: size,
                clippingImageWith: clipShape,
                with: .autoZoomTo(targetOffset),
            )
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .changed:
                state.applyTranslation(rawRelative: recognizer.translation(in: recognizer.view))
                recognizer.setTranslation(.zero, in: recognizer.view)
            case .possible, .began, .ended, .cancelled, .failed:
                // This gesture cannot initiate, so allow the pinch gesture to update the state.
                break
            @unknown default:
                logger.warning("received unknown pan gesture recognizer state=\(recognizer.state.rawValue)")
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            // The pan recognizer only exists to track finger drift during a pinch.
            // Don't let it recognize on its own.
            if gestureRecognizer === panRecognizer {
                // Two-finger pan handling (pun intended) is intended to complement pinch gestures.
                return initiatingGestures.allowsPinch && (
                    pinchRecognizer.state == .began
                    || pinchRecognizer.state == .changed
                )
            }

            // Don't open the preview via tap if the user is touching down to arrest a
            // scrolling or bouncing-back scroll view.
            //
            // This is a bit of a hack, partly because of the amount of introspection and partly
            // because it only works with scroll views, and only the nearest at that.
            if gestureRecognizer === tapRecognizer {
                guard initiatingGestures.allowsTap else { return false }

                if let scrollView = gestureRecognizer.view?.firstScrollViewAncestor {
                    return !scrollView.isDecelerating && !scrollView.isOutOfBounds
                }
            }

            if gestureRecognizer === pinchRecognizer {
                return initiatingGestures.allowsPinch
            }

            return true
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // While pinching, block any pan gestures not on our own view. This prevents scrolls,
            // sheet dismisses, and things like that.
            if gestureRecognizer === pinchRecognizer,
               other is UIPanGestureRecognizer,
               other !== panRecognizer {
                false
            } else {
                // Required to allow zoom/pan at the same time.
                true
            }
        }
    }
}

private extension UIView {
    var firstScrollViewAncestor: UIScrollView? {
        var view = superview
        // swiftlint:disable:next identifier_name
        while let v = view {
            if let scrollView = v as? UIScrollView {
                return scrollView
            }
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
