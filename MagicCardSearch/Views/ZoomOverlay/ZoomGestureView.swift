import SwiftUI

/// A transparent UIView overlay that installs pinch, rotation, and 2-finger pan
/// gesture recognizers, all recognizing simultaneously. Drives ZoomOverlayManager
/// for the originating gesture phase.
struct ZoomGestureView: UIViewRepresentable {
    let uiImage: UIImage
    let sourceFrame: CGRect
    let cornerRadius: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(uiImage: uiImage, sourceFrame: sourceFrame, cornerRadius: cornerRadius)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear

        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan))
        pan.minimumNumberOfTouches = 2
        pan.maximumNumberOfTouches = 2

        pinch.delegate = context.coordinator
        pan.delegate = context.coordinator

        view.addGestureRecognizer(pinch)
        view.addGestureRecognizer(pan)

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    @MainActor
    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        private let uiImage: UIImage
        private let sourceFrame: CGRect
        private let cornerRadius: CGFloat
        private var manager: ZoomOverlayManager { .shared }

        init(uiImage: UIImage, sourceFrame: CGRect, cornerRadius: CGFloat) {
            self.uiImage = uiImage
            self.sourceFrame = sourceFrame
            self.cornerRadius = cornerRadius
        }

        private func presentIfNeeded() {
            if !manager.isVisible {
                manager.present(image: uiImage, from: sourceFrame, cornerRadius: cornerRadius)
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                presentIfNeeded()
                let dScale = recognizer.scale
                recognizer.scale = 1
                // Centroid in screen space, converted to offset from image center.
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                let cx = centroid.x - imageCenterX
                let cy = centroid.y - imageCenterY
                // Translate so the point under the fingers stays fixed.
                manager.offset.width += cx * (1 - dScale)
                manager.offset.height += cy * (1 - dScale)
                manager.scale *= dScale
            case .ended, .cancelled, .failed:
                manager.commitGesture()
            default:
                break
            }
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                presentIfNeeded()
                let t = recognizer.translation(in: recognizer.view)
                manager.offset.width += t.x
                manager.offset.height += t.y
                recognizer.setTranslation(.zero, in: recognizer.view)
            default:
                break
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool { true }
    }
}
