import SwiftUI
import Combine

@MainActor
final class ZoomOverlayManager: ObservableObject {
    static let shared = ZoomOverlayManager()

    @Published var isVisible: Bool = false
    /// True while the originating gesture in CardFaceView still owns the transform.
    @Published var isGestureActive: Bool = false
    @Published var image: UIImage?
    @Published var sourceFrame: CGRect = .zero
    @Published var scale: CGFloat = 1
    @Published var offset: CGSize = .zero
    @Published var clipShape: AnyShape?

    private init() {}

    func present(image: UIImage, from frame: CGRect, clipShape: AnyShape?) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isGestureActive = true
        self.isVisible = true
    }

    /// Presents the overlay, animates to fullOpacityScale, and centers the image on screen.
    func presentFilled(image: UIImage, from frame: CGRect, clipShape: AnyShape? = nil, screenSize: CGSize) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isGestureActive = false
        self.isVisible = true
        let targetOffset = CGSize(
            width: screenSize.width / 2 - frame.midX,
            height: screenSize.height / 2 - frame.midY
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.scale = ZoomOverlayConstants.fullOpacityScale
            self.offset = targetOffset
        }
    }

    /// Called on onEnded of the originating gesture. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below 1. Snaps back to bounds
    /// if scale is outside [minScale, maxScale].
    func commitGesture() {
        isGestureActive = false
        if scale <= ZoomOverlayConstants.minScale {
            dismiss()
        } else if scale > ZoomOverlayConstants.maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = ZoomOverlayConstants.maxScale
            }
        }
    }

    func snapToBoundsIfNeeded() {
        if scale < ZoomOverlayConstants.minScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = ZoomOverlayConstants.minScale
            }
        } else if scale > ZoomOverlayConstants.maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = ZoomOverlayConstants.maxScale
            }
        }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1
            offset = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isVisible = false
            self.image = nil
        }
    }

    /// Flings the card a short distance in the direction of `velocity`,
    /// then animates back to the source position and dismisses.
    func fling(velocity: CGVector) {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        guard speed > 0 else { dismiss(); return }

        let normalX = velocity.dx / speed
        let normalY = velocity.dy / speed
        let flingOffset = CGSize(
            width: offset.width + normalX * ZoomOverlayConstants.flingDistance,
            height: offset.height + normalY * ZoomOverlayConstants.flingDistance
        )

        let flingDuration: Double = 0.12
        withAnimation(.easeOut(duration: flingDuration)) {
            offset = flingOffset
            scale = max(1, scale - 0.15)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + flingDuration) {
            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                self.scale = 1
                self.offset = .zero
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                self.isVisible = false
                self.image = nil
            }
        }
    }
}
