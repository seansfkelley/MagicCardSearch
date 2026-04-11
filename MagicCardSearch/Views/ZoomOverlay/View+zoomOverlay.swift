import SwiftUI

extension View {
    /// Makes this view's image zoomable. Apply to any image view; the source image is hidden while the overlay is active.
    /// - Parameter zoomBasisAdjustment: Scales all zoom thresholds (retain min, rubber-band max, opacity ramp)
    ///   proportionally. Use a value greater than 1.0 for small views that need to scale more to reach a desired minimum
    ///   visual size before the gesture is considered "committed". Values below 1.0 are clamped to 1.0. The value may
    ///   change, but it is only consulted at the time the overlay is first shown, so changes are not respected until any
    ///   current overlay is first dismissed.
    func zoomOverlay(
        for uiImage: UIImage?,
        clippingTo clipShape: AnyShape? = nil,
        initatedWith initiatingGestures: ZoomOverlayInitationGestures = .tapAndPinch,
        zoomBasisAdjustment: CGFloat = 1.0,
    ) -> some View {
        modifier(
            ZoomOverlayModifier(
                uiImage: uiImage,
                clipShape: clipShape,
                initiatingGestures: initiatingGestures,
                zoomBasisAdjustment: zoomBasisAdjustment,
            ),
        )
    }
}

private struct ZoomOverlayModifier: ViewModifier {
    let uiImage: UIImage?
    let clipShape: AnyShape?
    let initiatingGestures: ZoomOverlayInitationGestures
    let zoomBasisAdjustment: CGFloat

    @ObservedObject private var state = ZoomOverlayState.shared

    func body(content: Content) -> some View {
        content
            .opacity(isOverlayActiveForThisImage ? 0 : 1)
            .overlay {
                if let uiImage {
                    ZoomOverlayInitiatingGestureView(
                        uiImage: uiImage,
                        clipShape: clipShape,
                        initiatingGestures: initiatingGestures,
                        zoomBasisAdjustment: zoomBasisAdjustment,
                    )
                }
            }
    }

    private var isOverlayActiveForThisImage: Bool {
        guard let uiImage, state.isVisible else { return false }
        return state.image?.cgImage === uiImage.cgImage
    }
}
