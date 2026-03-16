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
    @Published public private(set) var scale: CGFloat = 1
    @Published public private(set) var offset: CGSize = .zero

    private init() {}

    // MARK: - Gesture Lifecycle

    /// Shows the overlay with the given location/size and resets transforms.
    func show(
        image: UIImage,
        in frame: CGRect,
        screenSize: CGSize,
        withGesture: Bool,
        clippingTo clipShape: AnyShape? = nil,
        andZoomTo zoomTo: CGSize? = nil,
    ) {
        self.image = image
        self.sourceFrame = frame
        self.screenSize = screenSize
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isVisible = true
        self.isInitiatingGesture = withGesture

        if let zoomTo {
            withAnimation(ZoomOverlayConstants.presentCenteredAnimation) {
                scale = ZoomOverlayConstants.maxOpacityReachedAtScaleFactor
                offset = zoomTo
            }
        }
    }

    /// Called when the originating pinch gesture ends. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below minScale.
    func initiatingGestureFinished() {
        isInitiatingGesture = false

        finishedScaling()
        // This is not-DRY but I couldn't figure out how to only pan if the zoom decided we should
        // stick around without breaking things up into a bunch of smaller private methods. This
        // is close enough.
        if scale >= ZoomOverlayConstants.minRetainedZoomScale {
            finishedPanning()
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
        guard speed > 0 else {
            dismiss()
            return
        }

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

    // MARK: - Gesture Math

    /// Applies a pinch update to scale and offset, rubber-banding scale at the limits.
    /// `scale` is the cumulative scale factor since the gesture began. `centroid` is in screen coordinates.
    func applyScale(_ newScale: CGFloat, aroundCentroid centroid: CGPoint) {
        let rubberBandedScale = rubberBand(
            newScale,
            min: ZoomOverlayConstants.minRetainedZoomScale,
            max: ZoomOverlayConstants.maxNonRubberBandingZoomScale,
            coefficient: ZoomOverlayConstants.scaleRubberBandCoefficient
        )
        let effectiveScale = rubberBandedScale / scale
        let imageCenterX = sourceFrame.midX + offset.width
        let imageCenterY = sourceFrame.midY + offset.height
        offset.width += (centroid.x - imageCenterX) * (1 - effectiveScale)
        offset.height += (centroid.y - imageCenterY) * (1 - effectiveScale)
        scale = rubberBandedScale
    }

    func applyTranslation(rawRelative translation: CGPoint) {
        offset.width += translation.x
        offset.height += translation.y
    }

    func applyTranslation(rubberBandedFromAbsolute translation: CGSize) {
        let (boundsX, boundsY) = panBounds()
        offset = CGSize(
            width: rubberBand(
                translation.width,
                min: boundsX.min,
                max: boundsX.max,
                coefficient: ZoomOverlayConstants.panRubberBandCoefficient,
            ),
            height: rubberBand(
                translation.height,
                min: boundsY.min,
                max: boundsY.max,
                coefficient: ZoomOverlayConstants.panRubberBandCoefficient,
            )
        )
    }

    // MARK: - Bounds Enforcement

    /// Snaps scale to [minScale, maxScale] if outside bounds.
    func finishedScaling() {
        if scale < ZoomOverlayConstants.minRetainedZoomScale {
            dismiss()
        } else if scale > ZoomOverlayConstants.maxNonRubberBandingZoomScale {
            withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                scale = ZoomOverlayConstants.maxNonRubberBandingZoomScale
            }
        }
    }

    /// Snaps pan offset to the allowed bounds if it's currently outside them.
    func finishedPanning() {
        let (boundsX, boundsY) = panBounds()

        var newOffset = CGSize(
            width: max(boundsX.min, min(boundsX.max, offset.width)),
            height: max(boundsY.min, min(boundsY.max, offset.height)),
        )

        if newOffset != offset {
            withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                offset = newOffset
            }
        }
    }

    // MARK: - Pan Bounds

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
