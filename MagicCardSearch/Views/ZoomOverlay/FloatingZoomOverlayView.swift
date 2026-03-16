import SwiftUI

struct FloatingZoomOverlayView: View {
    @EnvironmentObject private var manager: ZoomOverlayManager

    var body: some View {
        ZStack {
            if manager.isVisible, let image = manager.image {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: manager.sourceFrame.width, height: manager.sourceFrame.height)
                    .if(manager.clipShape != nil) { $0.clipShape(manager.clipShape!) }
                    .scaleEffect(manager.scale)
                    .offset(x: manager.offset.width, y: manager.offset.height)
                    .position(x: manager.sourceFrame.midX, y: manager.sourceFrame.midY)
                    .allowsHitTesting(false)

                if !manager.isInitiatingGesture {
                    OverlayGestureView()
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        let t = (Double(manager.scale) - ZoomOverlayConstants.minScale) / (ZoomOverlayConstants.fullOpacityScale - ZoomOverlayConstants.minScale)
        return UnitCurve.easeOut.value(at: max(0, min(1, t))) * ZoomOverlayConstants.fullOpacity
    }
}

/// Full-screen UIKit gesture view for the post-commit overlay phase.
/// Covers the entire window so gestures on the background also register.
private struct OverlayGestureView: UIViewRepresentable {
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

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)
        view.addGestureRecognizer(tap)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private var manager: ZoomOverlayManager { .shared }
        private var scaleAtGestureBegan: CGFloat = 1
        private var rawPanOffset: CGSize = .zero

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                scaleAtGestureBegan = manager.scale
            case .changed:
                let rawScale = scaleAtGestureBegan * recognizer.scale
                let clampedScale = rubberBand(rawScale, min: ZoomOverlayConstants.minScale, max: ZoomOverlayConstants.maxScale, coefficient: ZoomOverlayConstants.scaleRubberBandCoefficient)
                let effectiveDScale = clampedScale / manager.scale
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                manager.offset.width += (centroid.x - imageCenterX) * (1 - effectiveDScale)
                manager.offset.height += (centroid.y - imageCenterY) * (1 - effectiveDScale)
                manager.scale = clampedScale
            case .ended:
                manager.snapScaleToBoundsIfNeeded()
                if manager.scale <= ZoomOverlayConstants.minScale { manager.dismiss() }
            case .cancelled, .failed:
                manager.dismiss()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            let screenSize = recognizer.view?.window?.screen.bounds.size ?? UIScreen.main.bounds.size
            switch recognizer.state {
            case .began:
                rawPanOffset = manager.offset
            case .changed:
                let t = recognizer.translation(in: nil)
                rawPanOffset.width += t.x
                rawPanOffset.height += t.y
                recognizer.setTranslation(.zero, in: nil)
                manager.offset = manager.rubberBandedPanOffset(raw: rawPanOffset, screenSize: screenSize)
            case .ended:
                let v = recognizer.velocity(in: nil)
                let speed = sqrt(v.x * v.x + v.y * v.y)
                guard manager.scale > ZoomOverlayConstants.minScale else { break }
                if speed > ZoomOverlayConstants.flingVelocityThreshold {
                    manager.fling(velocity: CGVector(dx: v.x, dy: v.y))
                } else {
                    manager.snapPanOffsetIfNeeded(screenSize: screenSize)
                }
            default:
                break
            }
        }

        @objc func handleTap(_ recognizer: UITapGestureRecognizer) {
            manager.dismiss()
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
