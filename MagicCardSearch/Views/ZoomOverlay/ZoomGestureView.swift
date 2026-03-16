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

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2

        pinch.delegate = context.coordinator
        pan.delegate = context.coordinator
        tap.delegate = context.coordinator

        // Tap only fires if pinch hasn't recognized.
        tap.require(toFail: pinch)

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

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
        // Raw (unrubber-banded) offset accumulated during a pan gesture.
        private var rawPanOffset: CGSize = .zero

        init(uiImage: UIImage, clipShape: AnyShape?) {
            self.uiImage = uiImage
            self.clipShape = clipShape
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
                manager.commitPinchGesture()
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
            let screenSize = recognizer.view?.window?.screen.bounds.size ?? UIScreen.main.bounds.size
            switch recognizer.state {
            case .began:
                if let view = recognizer.view { presentIfNeeded(view: view) }
                rawPanOffset = manager.offset
            case .changed:
                if let view = recognizer.view { presentIfNeeded(view: view) }
                let t = recognizer.translation(in: recognizer.view)
                rawPanOffset.width += t.x
                rawPanOffset.height += t.y
                recognizer.setTranslation(.zero, in: recognizer.view)
                manager.offset = manager.rubberBandedPanOffset(raw: rawPanOffset, screenSize: screenSize)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // While pinching, block any pan gestures not on our own view
            // (scroll views, sheet dismiss, etc.).
            if gestureRecognizer is UIPinchGestureRecognizer,
               other is UIPanGestureRecognizer,
               other.view !== gestureRecognizer.view {
                return false
            }
            return true
        }
    }
}
