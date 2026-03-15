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
    @Published var rotation: Angle = .zero
    @Published var cornerRadius: CGFloat = 0

    private init() {}

    func present(image: UIImage, from frame: CGRect, cornerRadius: CGFloat) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.rotation = .zero
        self.cornerRadius = cornerRadius
        self.isGestureActive = true
        self.isVisible = true
    }

    /// Called on onEnded of the originating gesture. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below 1.
    func commitGesture() {
        isGestureActive = false
        if scale <= 1 {
            dismiss()
        }
    }

    func dismiss() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            scale = 1
            offset = .zero
            rotation = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isVisible = false
            self.image = nil
        }
    }
}
