import SwiftUI

extension View {
    func zoomOverlay(for uiImage: UIImage?, clippingTo clipShape: AnyShape? = nil) -> some View {
        modifier(ZoomOverlayModifier(uiImage: uiImage, clipShape: clipShape))
    }
}

private struct ZoomOverlayModifier: ViewModifier {
    let uiImage: UIImage?
    let clipShape: AnyShape?

    @ObservedObject private var state = ZoomOverlayState.shared

    func body(content: Content) -> some View {
        content
            .opacity(isOverlayActiveForThisImage ? 0 : 1)
            .overlay {
                if let uiImage {
                    ZoomOverlayInitiatingGestureView(uiImage: uiImage, clipShape: clipShape)
                }
            }
    }

    private var isOverlayActiveForThisImage: Bool {
        guard let uiImage, state.isVisible else { return false }
        return state.image === uiImage
    }
}
