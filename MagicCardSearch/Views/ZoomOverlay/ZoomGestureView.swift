import SwiftUI

/// Returns a rubber-banded value when `raw` exceeds [min, max].
/// `coefficient` controls resistance: smaller = gentler (more travel past bound),
/// larger = stiffer. Uses the standard UIScrollView-style formula: excess / (1 + excess * coefficient).
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

/// A transparent UIView overlay that installs pinch and 2-finger pan
/// gesture recognizers, all recognizing simultaneously. Drives ZoomOverlayManager
/// for the originating gesture phase.
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

        // Scale at the moment the pinch began, used to compute cumulative scale
        // so rubber-banding sees total overshoot rather than per-frame deltas.
        private var scaleAtGestureBegan: CGFloat = 1

        init(uiImage: UIImage, clipShape: AnyShape?) {
            self.uiImage = uiImage
            self.clipShape = clipShape
        }

        private func currentFrame(for view: UIView) -> CGRect {
            view.convert(view.bounds, to: nil)
        }

        private func presentIfNeeded(view: UIView) {
            if !manager.isVisible {
                manager.present(image: uiImage, from: currentFrame(for: view), clipShape: clipShape)
            }
        }

        @objc func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let view = recognizer.view else { return }
            switch recognizer.state {
            case .began:
                presentIfNeeded(view: view)
                scaleAtGestureBegan = manager.scale
            case .changed:
                presentIfNeeded(view: view)
                // recognizer.scale is cumulative since .began, matching MagnificationGesture.value.
                let rawScale = scaleAtGestureBegan * recognizer.scale
                let clampedScale = rubberBand(rawScale, min: ZoomOverlayConstants.minScale, max: ZoomOverlayConstants.maxScale)
                let effectiveDScale = clampedScale / manager.scale
                // Centroid in screen space, converted to offset from image center.
                let centroid = recognizer.location(in: nil)
                let imageCenterX = manager.sourceFrame.midX + manager.offset.width
                let imageCenterY = manager.sourceFrame.midY + manager.offset.height
                let cx = centroid.x - imageCenterX
                let cy = centroid.y - imageCenterY
                manager.offset.width += cx * (1 - effectiveDScale)
                manager.offset.height += cy * (1 - effectiveDScale)
                manager.scale = clampedScale
            case .ended:
                manager.commitGesture()
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
            manager.presentFilled(image: uiImage, from: currentFrame(for: view), clipShape: clipShape, screenSize: screenSize)
        }

        @objc func handlePan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                if let view = recognizer.view { presentIfNeeded(view: view) }
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
