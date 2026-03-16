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

    /// Rubber-bands a proposed offset value against [minOffset, maxOffset].
    /// When min > max (image smaller than screen in this axis), both collapse to 0 (centered).
    func rubberBandOffset(_ proposed: CGFloat, min minOffset: CGFloat, max maxOffset: CGFloat) -> CGFloat {
        if minOffset > maxOffset {
            // Image fits within screen on this axis — rubber-band back to center (0).
            return proposed / (1 + abs(proposed) * 0.008)
        }
        if proposed < minOffset {
            let excess = minOffset - proposed
            return minOffset - excess / (1 + excess * 0.008)
        }
        if proposed > maxOffset {
            let excess = proposed - maxOffset
            return maxOffset + excess / (1 + excess * 0.008)
        }
        return proposed
    }

    /// Returns the allowed (minOffset, maxOffset) for one axis of panning.
    /// - Parameters:
    ///   - scaledImageSize: The image's rendered size on that axis (sourceFrame * scale).
    ///   - sourceCenter: The image's anchor position on that axis (sourceFrame.mid{X,Y}).
    ///   - screenSize: The screen dimension on that axis.
    ///   - minScreenDimension: The smaller of the two screen dimensions, for buffer calculation.
    func panBoundsForAxis(
        scaledImageSize: CGFloat,
        sourceCenter: CGFloat,
        screenSize: CGFloat,
        minScreenDimension: CGFloat
    ) -> (min: CGFloat, max: CGFloat) {
        let buffer = minScreenDimension * ZoomOverlayConstants.panEdgeBufferFraction
        // Offset that would center the image on screen.
        let centeringOffset = screenSize / 2 - sourceCenter
        let overflow = (scaledImageSize - screenSize) / 2
        if overflow <= 0 {
            // Image fits within screen — only valid position is centered.
            return (min: centeringOffset, max: centeringOffset)
        }
        return (min: centeringOffset - overflow - buffer, max: centeringOffset + overflow + buffer)
    }

    /// Snaps offset to pan bounds with a spring animation if it's outside them.
    func snapOffsetToPanBoundsIfNeeded(screenSize: CGSize) {
        let scaledW = sourceFrame.width * scale
        let scaledH = sourceFrame.height * scale
        let minDim = min(screenSize.width, screenSize.height)
        let boundsX = panBoundsForAxis(scaledImageSize: scaledW, sourceCenter: sourceFrame.midX, screenSize: screenSize.width, minScreenDimension: minDim)
        let boundsY = panBoundsForAxis(scaledImageSize: scaledH, sourceCenter: sourceFrame.midY, screenSize: screenSize.height, minScreenDimension: minDim)

        var newOffset = offset
        newOffset.width = max(boundsX.min, min(boundsX.max, newOffset.width))
        newOffset.height = max(boundsY.min, min(boundsY.max, newOffset.height))

        if newOffset != offset {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                offset = newOffset
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
