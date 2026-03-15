import SwiftUI

private let minScale: CGFloat = 1.0
private let maxScale: CGFloat = 2.0

private func rubberBand(_ raw: CGFloat, min: CGFloat, max: CGFloat, coefficient: CGFloat = 0.15) -> CGFloat {
    if raw < min {
        let excess = min - raw
        return min - excess / (1 + excess * coefficient)
    } else if raw > max {
        let excess = raw - max
        return max + excess / (1 + excess * coefficient)
    }
    return raw
}

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
                    .clipShape(RoundedRectangle(cornerRadius: manager.cornerRadius))
                    .scaleEffect(manager.scale)
                    .offset(x: manager.offset.width, y: manager.offset.height)
                    .position(x: manager.sourceFrame.midX, y: manager.sourceFrame.midY)
                    .allowsHitTesting(false)

                if !manager.isGestureActive {
                    OverlayGestureView()
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        let liveScale = Double(manager.scale)
        let fullOpacityScaleFactor = 1.5
        let t = (liveScale - 1.0) / (fullOpacityScaleFactor - 1.0)
        return max(0, min(1, t))
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

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began:
                scaleAtGestureBegan = manager.scale
            case .changed:
                let rawScale = scaleAtGestureBegan * recognizer.scale
                let clampedScale = rubberBand(rawScale, min: minScale, max: maxScale)
                let effectiveDScale = clampedScale / manager.scale
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                let cx = centroid.x - imageCenterX
                let cy = centroid.y - imageCenterY
                manager.offset.width += cx * (1 - effectiveDScale)
                manager.offset.height += cy * (1 - effectiveDScale)
                manager.scale = clampedScale
            case .ended:
                manager.snapToBoundsIfNeeded()
                if manager.scale <= minScale { manager.dismiss() }
            case .cancelled, .failed:
                manager.dismiss()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            guard recognizer.state == .changed || recognizer.state == .began else { return }
            let t = recognizer.translation(in: nil)
            manager.offset.width += t.x
            manager.offset.height += t.y
            recognizer.setTranslation(.zero, in: nil)
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
