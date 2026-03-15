import SwiftUI
import Combine

@MainActor
final class ZoomOverlayManager: ObservableObject {
    static let shared = ZoomOverlayManager()

    @Published var isVisible: Bool = false
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
        self.isVisible = true
    }

    func dismiss() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            scale = 1
            offset = .zero
            rotation = .zero
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            self.isVisible = false
        }
    }
}
