import SwiftUI

@MainActor
final class ZoomOverlayState: ObservableObject {
    static let shared = ZoomOverlayState()

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isInitiatingGesture: Bool = false
    @Published public private(set) var image: UIImage?
    @Published public private(set) var sourceFrame: CGRect = .zero
    @Published public private(set) var clipShape: AnyShape?
    @Published public private(set) var screenSize: CGSize = .zero

    @Published public var scale: CGFloat = 1
    @Published public var offset: CGSize = .zero

    private init() {}

    // MARK: - Gesture Lifecycle

    /// Shows the overlay with the given location/size and resets transforms.
    func show(
        image: UIImage,
        in frame: CGRect,
        screenSize: CGSize,
        withGesture: Bool,
        clippingTo clipShape: AnyShape? = nil,
    ) {
        self.image = image
        self.sourceFrame = frame
        self.screenSize = screenSize
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isVisible = true
        self.isInitiatingGesture = withGesture
    }

    /// Called when the originating pinch gesture ends. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below minScale.
    func maybeCommitInitiatingGesture() {
        isInitiatingGesture = false
        if scale <= ZoomOverlayConstants.minRetainedZoomScale {
            dismiss()
        } else {
            if scale > ZoomOverlayConstants.maxNonRubberBandingZoomScale {
                withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                    scale = ZoomOverlayConstants.maxNonRubberBandingZoomScale
                }
            }
            snapToPanBounds()
        }
    }

    /// Animates scale and offset back to identity, then hides the overlay.
    func dismiss() {
        withAnimation(ZoomOverlayConstants.snapBackAnimation, completionCriteria: .logicallyComplete) {
            scale = 1
            offset = .zero
        } completion: {
            self.isVisible = false
            self.image = nil
        }
    }

    /// Throws the image in the fling direction, then springs back and dismisses.
    func dismiss(withFling velocity: CGVector) {
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        guard speed > 0 else { dismiss(); return }

        let normalX = velocity.dx / speed
        let normalY = velocity.dy / speed
        let flingOffset = CGSize(
            width: offset.width + normalX * ZoomOverlayConstants.flingDistance,
            height: offset.height + normalY * ZoomOverlayConstants.flingDistance
        )

        withAnimation(ZoomOverlayConstants.flingThrowAnimation, completionCriteria: .logicallyComplete) {
            offset = flingOffset
            scale = max(1, scale - ZoomOverlayConstants.flingScaleReduction)
        } completion: {
            withAnimation(ZoomOverlayConstants.flingReturnAnimation, completionCriteria: .logicallyComplete) {
                self.scale = 1
                self.offset = .zero
            } completion: {
                self.isVisible = false
                self.image = nil
            }
        }
    }

    // MARK: - Bounds Enforcement

    /// Snaps scale to [minScale, maxScale] if outside bounds.
    func snapToScaleBounds() {
        if scale < ZoomOverlayConstants.minRetainedZoomScale {
            withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                scale = ZoomOverlayConstants.minRetainedZoomScale
            }
        } else if scale > ZoomOverlayConstants.maxNonRubberBandingZoomScale {
            withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                scale = ZoomOverlayConstants.maxNonRubberBandingZoomScale
            }
        }
    }

    /// Snaps pan offset to the allowed bounds if it's currently outside them.
    func snapToPanBounds() {
        let (boundsX, boundsY) = panBounds()

        var newOffset = offset
        newOffset.width = max(boundsX.min, min(boundsX.max, newOffset.width))
        newOffset.height = max(boundsY.min, min(boundsY.max, newOffset.height))

        if newOffset != offset {
            withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                offset = newOffset
            }
        }
    }

    // MARK: - Pan Bounds

    /// Returns the rubber-banded display offset for a proposed raw pan offset.
    func rubberBandedPanOffset(raw: CGSize) -> CGSize {
        let (boundsX, boundsY) = panBounds()
        return CGSize(
            width: rubberBand(
                raw.width,
                min: boundsX.min,
                max: boundsX.max,
                coefficient: ZoomOverlayConstants.panRubberBandCoefficient,
            ),
            height: rubberBand(
                raw.height,
                min: boundsY.min,
                max: boundsY.max,
                coefficient: ZoomOverlayConstants.panRubberBandCoefficient,
            )
        )
    }

    /// Returns the allowed (min, max) offset range for both axes.
    private func panBounds() -> (x: (min: CGFloat, max: CGFloat), y: (min: CGFloat, max: CGFloat)) {
        let padding = min(screenSize.width, screenSize.height) * ZoomOverlayConstants.panEdgeBufferFraction

        func boundsForAxis(
            sourceContentLength: CGFloat,
            sourceCenter: CGFloat,
            axisLength: CGFloat,
        ) -> (min: CGFloat, max: CGFloat) {
            let centeringOffset = axisLength / 2 - sourceCenter
            let overflow = (sourceContentLength * scale - axisLength) / 2
            return if overflow > 0 {
                (min: centeringOffset - overflow - padding, max: centeringOffset + overflow + padding)
            } else {
                (min: centeringOffset, max: centeringOffset)
            }
        }

        return (
            x: boundsForAxis(
                sourceContentLength: sourceFrame.width,
                sourceCenter: sourceFrame.midX,
                axisLength: screenSize.width
            ),
            y: boundsForAxis(
                sourceContentLength: sourceFrame.height,
                sourceCenter: sourceFrame.midY,
                axisLength: screenSize.height
            )
        )
    }
}
