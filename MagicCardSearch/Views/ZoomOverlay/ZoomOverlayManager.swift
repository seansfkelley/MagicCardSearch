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
    @Published var cornerRadius: CGFloat = 0

    static let minScale: CGFloat = 1.0
    static let maxScale: CGFloat = 1.7
    /// The scale at which the background reaches full black.
    static let fullOpacityScale: CGFloat = 1.4

    private init() {}

    func present(image: UIImage, from frame: CGRect, cornerRadius: CGFloat) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.cornerRadius = cornerRadius
        self.isGestureActive = true
        self.isVisible = true
    }

    /// Presents the overlay, animates to fullOpacityScale, and centers the image on screen.
    func presentFilled(image: UIImage, from frame: CGRect, cornerRadius: CGFloat, screenSize: CGSize) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.cornerRadius = cornerRadius
        self.isGestureActive = false
        self.isVisible = true
        let targetOffset = CGSize(
            width: screenSize.width / 2 - frame.midX,
            height: screenSize.height / 2 - frame.midY
        )
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            self.scale = ZoomOverlayManager.fullOpacityScale
            self.offset = targetOffset
        }
    }

    /// Called on onEnded of the originating gesture. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below 1. Snaps back to bounds
    /// if scale is outside [minScale, maxScale].
    func commitGesture() {
        isGestureActive = false
        if scale <= Self.minScale {
            dismiss()
        } else if scale > Self.maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = Self.maxScale
            }
        }
    }

    func snapToBoundsIfNeeded() {
        if scale < Self.minScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = Self.minScale
            }
        } else if scale > Self.maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = Self.maxScale
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
}
