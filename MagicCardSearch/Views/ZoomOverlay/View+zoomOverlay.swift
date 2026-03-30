import SwiftUI

extension View {
    /// Makes this view's image zoomable. Apply to any image view; the source image is hidden while the overlay is active.
    func zoomOverlay(
        for uiImage: UIImage?,
        clippingTo clipShape: AnyShape? = nil,
        initatedWith initiatingGestures: ZoomOverlayInitationGestures = .tapAndPinch,
    ) -> some View {
        modifier(ZoomOverlayModifier(uiImage: uiImage, clipShape: clipShape, initiatingGestures: initiatingGestures))
    }
}

private struct ZoomOverlayModifier: ViewModifier {
    let uiImage: UIImage?
    let clipShape: AnyShape?
    let initiatingGestures: ZoomOverlayInitationGestures

    @ObservedObject private var state = ZoomOverlayState.shared

    func body(content: Content) -> some View {
        content
            .opacity(isOverlayActiveForThisImage ? 0 : 1)
            .overlay {
                if let uiImage {
                    ZoomOverlayInitiatingGestureView(uiImage: uiImage, clipShape: clipShape, initiatingGestures: initiatingGestures)
                }
            }
    }

    private var isOverlayActiveForThisImage: Bool {
        guard let uiImage, state.isVisible else { return false }
        return state.image === uiImage
    }
}
