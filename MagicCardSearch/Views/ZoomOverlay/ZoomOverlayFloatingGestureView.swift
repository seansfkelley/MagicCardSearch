import SwiftUI
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "ZoomOverlayFloatingGestureView")

/// Full-screen UIKit gesture view for the post-commit overlay phase.
/// Covers the entire window so gestures on the background also register.
struct ZoomOverlayFloatingGestureView: UIViewRepresentable {
    func makeCoordinator() -> Coordinator { Coordinator() }

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
        private var state: ZoomOverlayState { .shared }
        private var rawOffset: CGSize = .zero

        lazy var pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch))
        lazy var tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        lazy var panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan))

        override init() {
            super.init()
            pinchRecognizer.delegate = self
            tapRecognizer.delegate = self
            panRecognizer.delegate = self
            // Tap only fires if pan hasn't recognized first.
            tapRecognizer.require(toFail: panRecognizer)
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                recognizer.scale = state.scale
            case .changed:
                state.applyScale(recognizer.scale, aroundCentroid: recognizer.location(in: nil))
            case .ended, .cancelled, .failed:
                state.finishedScaling()
            case .possible:
                break
            @unknown default:
                logger.warning("received unknown pinch gesture recognizer state=\(recognizer.state.rawValue)")
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            state.dismiss()
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began:
                rawOffset = state.translation
            case .changed:
                // swiftlint:disable:next identifier_name
                let t = recognizer.translation(in: nil)
                // I would prefer to not accumulate the offset like this, but it's necessary to be
                // able to incrementally apply the offset during a simultaneous pinch, below.
                // Applying the offset as an absolute would still require keeping track of what the
                // offset was when the pan began to back out the delta, again to avoid fighting the
                // pinch gesture.
                rawOffset.width += t.x
                rawOffset.height += t.y
                recognizer.setTranslation(.zero, in: nil)
                if pinchRecognizer.state == .began || pinchRecognizer.state == .changed {
                    // During a simultaneous pinch+pan, apply translation directly so it
                    // doesn't fight the pinch centroid math with rubber-band resistance.
                    state.applyTranslation(rawRelative: t)
                    // TODO: This used to update rawOffset to state.offset in the case the pinch
                    // ended but we kept panning, but that doesn't seem to be necessary.
                } else {
                    state.applyTranslation(rubberBandedFromAbsolute: rawOffset)
                }
            case .ended:
                // swiftlint:disable:next identifier_name
                let v = recognizer.velocity(in: nil)
                let speed = sqrt(v.x * v.x + v.y * v.y)

                // The pinch gesture will handle dismissing instead.
                guard state.scale > ZoomOverlayConstants.minRetainedZoomScale else { break }

                if speed > ZoomOverlayConstants.flingVelocityThreshold {
                    state.dismiss(withFling: CGVector(dx: v.x, dy: v.y))
                } else {
                    state.finishedTranslating()
                }
            case .possible, .cancelled, .failed:
                break
            @unknown default:
                logger.warning("received unknown pan gesture recognizer state=\(recognizer.state.rawValue)")
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            // Required to allow zoom/pan at the same time.
            true
        }
    }
}
