import SwiftUI

@MainActor
final class ZoomOverlayManager: ObservableObject {
    static let shared = ZoomOverlayManager()

    @Published var isVisible: Bool = false
    /// True while the originating gesture in ZoomGestureView still owns the transform.
    @Published var isInitiatingGesture: Bool = false
    @Published var image: UIImage?
    @Published var sourceFrame: CGRect = .zero
    @Published var scale: CGFloat = 1
    @Published var offset: CGSize = .zero
    @Published var clipShape: AnyShape?

    private init() {}

    // MARK: - Gesture Lifecycle

    /// Presents the overlay and optionally animates the image to fill the screen, centered.
    func initiate(with image: UIImage, from frame: CGRect, clippingTo clipShape: AnyShape? = nil, centeredIn screenSize: CGSize? = nil) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isInitiatingGesture = false
        self.isVisible = true
        if let screenSize {
            let targetOffset = CGSize(
                width: screenSize.width / 2 - frame.midX,
                height: screenSize.height / 2 - frame.midY
            )
            withAnimation(ZoomOverlayConstants.presentCenteredAnimation) {
                self.scale = ZoomOverlayConstants.fullOpacityReachedAtScaleFactor
                self.offset = targetOffset
            }
        }
    }

    /// Called when the originating pinch gesture ends. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below minScale.
    func maybeCommitInitiatingGesture(screenSize: CGSize) {
        isInitiatingGesture = false
        if scale <= ZoomOverlayConstants.minRetainedZoomScale {
            dismiss()
        } else {
            if scale > ZoomOverlayConstants.maxNonRubberBandingZoomScale {
                withAnimation(ZoomOverlayConstants.snapBackAnimation) {
                    scale = ZoomOverlayConstants.maxNonRubberBandingZoomScale
                }
            }
            snapToPanBounds(screenSize: screenSize)
        }
    }

    func dismiss() {
        withAnimation(ZoomOverlayConstants.snapBackAnimation, completionCriteria: .logicallyComplete) {
            scale = 1
            offset = .zero
        } completion: {
            self.isVisible = false
            self.image = nil
        }
    }

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
    func snapToPanBounds(screenSize: CGSize) {
        let (boundsX, boundsY) = panBounds(screenSize: screenSize)

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
    func rubberBandedPanOffset(raw: CGSize, screenSize: CGSize) -> CGSize {
        let (boundsX, boundsY) = panBounds(screenSize: screenSize)
        return CGSize(
            width: rubberBand(raw.width, min: boundsX.min, max: boundsX.max, coefficient: ZoomOverlayConstants.panRubberBandCoefficient),
            height: rubberBand(raw.height, min: boundsY.min, max: boundsY.max, coefficient: ZoomOverlayConstants.panRubberBandCoefficient)
        )
    }

    /// Returns the allowed (min, max) offset range for both axes.
    private func panBounds(screenSize: CGSize) -> (x: (min: CGFloat, max: CGFloat), y: (min: CGFloat, max: CGFloat)) {
        let buffer = min(screenSize.width, screenSize.height) * ZoomOverlayConstants.panEdgeBufferFraction

        func boundsForAxis(scaledImageSize: CGFloat, sourceCenter: CGFloat, axisLength: CGFloat) -> (min: CGFloat, max: CGFloat) {
            let centeringOffset = axisLength / 2 - sourceCenter
            let overflow = (scaledImageSize - axisLength) / 2
            return if overflow > 0 {
                (min: centeringOffset - overflow - buffer, max: centeringOffset + overflow + buffer)
            } else {
                (min: centeringOffset, max: centeringOffset)
            }
        }

        return (
            x: boundsForAxis(
                scaledImageSize: sourceFrame.width * scale,
                sourceCenter: sourceFrame.midX,
                axisLength: screenSize.width,
            ),
            y: boundsForAxis(
                scaledImageSize: sourceFrame.height * scale,
                sourceCenter: sourceFrame.midY,
                axisLength: screenSize.height,
            )
        )
    }
}
