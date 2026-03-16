import SwiftUI

/// Full-screen UIKit gesture view for the post-commit overlay phase.
/// Covers the entire window so gestures on the background also register.
struct ZoomOverlayFloatingGestureView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))

        pinch.delegate = context.coordinator
        pan.delegate = context.coordinator
        tap.delegate = context.coordinator

        context.coordinator.pinchRecognizer = pinch

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    // n.b. can't make this private and don't want to rename it, so can't pull it out to file scope
    // else it will collide with the other Coordinator and generally be vague.
    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var state: ZoomOverlayState { .shared }
        private var scaleAtGestureBegan: CGFloat = 1
        private var rawPanOffset: CGSize = .zero
        weak var pinchRecognizer: UIPinchGestureRecognizer?

        private var isPinchActive: Bool {
            pinchRecognizer?.state == .began || pinchRecognizer?.state == .changed
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                scaleAtGestureBegan = state.scale
            case .changed:
                let rawScale = scaleAtGestureBegan * recognizer.scale
                let clampedScale = rubberBand(rawScale, min: ZoomOverlayConstants.minRetainedZoomScale, max: ZoomOverlayConstants.maxNonRubberBandingZoomScale, coefficient: ZoomOverlayConstants.scaleRubberBandCoefficient)
                let effectiveDScale = clampedScale / state.scale
                let centroid = recognizer.location(in: nil)
                let imageCenterX = state.sourceFrame.midX + state.offset.width
                let imageCenterY = state.sourceFrame.midY + state.offset.height
                state.offset.width += (centroid.x - imageCenterX) * (1 - effectiveDScale)
                state.offset.height += (centroid.y - imageCenterY) * (1 - effectiveDScale)
                state.scale = clampedScale
            case .ended:
                state.snapToScaleBounds()
                if state.scale <= ZoomOverlayConstants.minRetainedZoomScale {
                    state.dismiss()
                }
            case .cancelled, .failed:
                state.dismiss()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                rawPanOffset = state.offset
            case .changed:
                let t = recognizer.translation(in: nil)
                rawPanOffset.width += t.x
                rawPanOffset.height += t.y
                recognizer.setTranslation(.zero, in: nil)
                if isPinchActive {
                    // During a simultaneous pinch+pan, apply translation directly so it
                    // doesn't fight the pinch centroid math with rubber-band resistance.
                    state.offset.width += t.x
                    state.offset.height += t.y
                    // Keep rawPanOffset synced so rubber-banding starts correctly if pinch ends.
                    rawPanOffset = state.offset
                } else {
                    state.offset = state.rubberBandedPanOffset(raw: rawPanOffset)
                }
            case .ended:
                let v = recognizer.velocity(in: nil)
                let speed = sqrt(v.x * v.x + v.y * v.y)
                guard state.scale > ZoomOverlayConstants.minRetainedZoomScale else { break }
                if speed > ZoomOverlayConstants.flingVelocityThreshold {
                    state.dismiss(withFling: CGVector(dx: v.x, dy: v.y))
                } else {
                    state.snapToPanBounds()
                }
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            state.dismiss()
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRequireFailureOf other: UIGestureRecognizer
        ) -> Bool {
            // Tap only fires if the pan hasn't recognized first.
            gestureRecognizer is UITapGestureRecognizer && other is UIPanGestureRecognizer
        }
    }
}
