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

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 2.0

    /// Called on onEnded of the originating gesture. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below 1. Snaps back to bounds
    /// if scale is outside [minScale, maxScale].
    func commitGesture() {
        isGestureActive = false
        if scale <= minScale {
            dismiss()
        } else if scale > maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = maxScale
            }
        }
    }

    func snapToBoundsIfNeeded() {
        if scale < minScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = minScale
            }
        } else if scale > maxScale {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                scale = maxScale
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
