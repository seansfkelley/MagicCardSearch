import SwiftUI

@MainActor
final class ZoomOverlayState: ObservableObject {
    static let shared = ZoomOverlayState(yesThisIsTheSingletonOrTestCode: true)

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isInitiatingGesture: Bool = false
    @Published public private(set) var image: UIImage?
    @Published public private(set) var sourceFrame: CGRect = .zero
    @Published public private(set) var clipShape: AnyShape?
    @Published public private(set) var screenSize: CGSize = .zero
    @Published public private(set) var scale: CGFloat = 1
    @Published public private(set) var translation: CGSize = .zero

    private let enableAnimations: Bool

    init(yesThisIsTheSingletonOrTestCode: Bool, enableAnimations: Bool = true) {
        self.enableAnimations = enableAnimations
    }

    enum ShowType {
        case continuingGesture
        case autoZoomTo(CGSize)
    }

    // MARK: - Gesture Lifecycle

    /// Shows the overlay with the given location/size and resets transforms.
    func show(
        image: UIImage,
        in frame: CGRect,
        screenSize: CGSize,
        clippingImageWith clipShape: AnyShape? = nil,
        with showType: ShowType,
    ) {
        self.image = image
        self.sourceFrame = frame
        self.screenSize = screenSize
        self.scale = 1
        self.translation = .zero
        self.clipShape = clipShape
        self.isVisible = true

        switch showType {
        case .continuingGesture:
            isInitiatingGesture = true
        case .autoZoomTo(let size):
            isInitiatingGesture = false
            animate(ZoomOverlayConstants.presentCenteredAnimation) {
                scale = ZoomOverlayConstants.maxOpacityReachedAtScaleFactor
                translation = size
            }
        }
    }

    /// Called when the originating pinch gesture ends. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below minScale.
    func initiatingGestureFinished() {
        guard isInitiatingGesture else { return }

        isInitiatingGesture = false

        finishedScaling()
        // This is not-DRY but I couldn't figure out how to only translate if the scale decided we
        // should stick around without breaking things up into a bunch of smaller private methods.
        // This is close enough.
        if scale >= ZoomOverlayConstants.minRetainedZoomScale {
            finishedTranslating()
        }
    }

    /// Animates scale and offset back to identity, then hides the overlay.
    func dismiss() {
        isInitiatingGesture = false

        animate(ZoomOverlayConstants.snapBackAnimation) {
            scale = 1
            translation = .zero
        } completion: {
            self.isVisible = false
            self.image = nil
        }
    }

    /// Throws the image in the fling direction, then springs back and dismisses.
    func dismiss(withFling velocity: CGVector) {
        isInitiatingGesture = false
        
        let speed = sqrt(velocity.dx * velocity.dx + velocity.dy * velocity.dy)
        guard speed > 0 else {
            dismiss()
            return
        }

        let normalX = velocity.dx / speed
        let normalY = velocity.dy / speed
        let flingOffset = CGSize(
            width: translation.width + normalX * ZoomOverlayConstants.flingDistance,
            height: translation.height + normalY * ZoomOverlayConstants.flingDistance
        )

        animate(ZoomOverlayConstants.flingThrowAnimation) {
            translation = flingOffset
            scale = max(1, scale - ZoomOverlayConstants.flingScaleReduction)
        } completion: {
            self.animate(ZoomOverlayConstants.flingReturnAnimation) {
                self.scale = 1
                self.translation = .zero
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
        let imageCenterX = sourceFrame.midX + translation.width
        let imageCenterY = sourceFrame.midY + translation.height
        translation.width += (centroid.x - imageCenterX) * (1 - effectiveScale)
        translation.height += (centroid.y - imageCenterY) * (1 - effectiveScale)
        scale = rubberBandedScale
    }

    func applyTranslation(rawRelative relative: CGPoint) {
        translation.width += relative.x
        translation.height += relative.y
    }

    func applyTranslation(rubberBandedFromAbsolute absolute: CGSize) {
        let (boundsX, boundsY) = translationBounds()
        translation = CGSize(
            width: rubberBand(
                absolute.width,
                min: boundsX.min,
                max: boundsX.max,
                coefficient: ZoomOverlayConstants.panRubberBandCoefficient,
            ),
            height: rubberBand(
                absolute.height,
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
            animate(ZoomOverlayConstants.snapBackAnimation) {
                scale = ZoomOverlayConstants.maxNonRubberBandingZoomScale
            }
        }
    }

    /// Snaps translation to the allowed bounds if it's currently outside them.
    func finishedTranslating() {
        let (boundsX, boundsY) = translationBounds()

        let newOffset = CGSize(
            width: max(boundsX.min, min(boundsX.max, translation.width)),
            height: max(boundsY.min, min(boundsY.max, translation.height)),
        )

        if newOffset != translation {
            animate(ZoomOverlayConstants.snapBackAnimation) {
                translation = newOffset
            }
        }
    }

    // MARK: - Translation Bounds

    /// Returns the allowed (min, max) offset range for both axes.
    private func translationBounds() -> (x: (min: CGFloat, max: CGFloat), y: (min: CGFloat, max: CGFloat)) {
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

    // MARK: - Animation Helpers

    // Runs `body` immediately when `disableAnimations` is true, otherwise wraps in `withAnimation`.
    private func animate(_ animation: Animation? = nil, _ body: () -> Void) {
        if enableAnimations {
            withAnimation(animation, body)
        } else {
            body()
        }
    }

    // Runs `body` immediately when `disableAnimations` is true, otherwise wraps in `withAnimation`
    // with a completion handler that fires after the logical animation completes.
    private func animate(
        _ animation: Animation?,
        _ body: () -> Void,
        completion: @escaping () -> Void
    ) {
        if enableAnimations {
            withAnimation(animation, completionCriteria: .logicallyComplete, body, completion: completion)
        } else {
            body()
            completion()
        }
    }
}

// Visible for testing.
/// Rubber-bands `raw` against [min, max] using the standard UIScrollView-style formula.
/// Values within bounds pass through unchanged; values outside are damped by `coefficient`.
/// Smaller coefficient = more stretch past the boundary.
func rubberBand(_ raw: CGFloat, min: CGFloat, max: CGFloat, coefficient: CGFloat) -> CGFloat {
    if raw < min {
        let excess = min - raw
        return min - excess / (1 + excess * coefficient)
    } else if raw > max {
        let excess = raw - max
        return max + excess / (1 + excess * coefficient)
    } else {
        return raw
    }
}
