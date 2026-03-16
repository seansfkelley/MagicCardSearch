import SwiftUI
import Combine

@MainActor
final class ZoomOverlayManager: ObservableObject {
    static let shared = ZoomOverlayManager()

    @Published var isVisible: Bool = false
    /// True while the originating gesture in ZoomGestureView still owns the transform.
    @Published var isGestureActive: Bool = false
    @Published var image: UIImage?
    @Published var sourceFrame: CGRect = .zero
    @Published var scale: CGFloat = 1
    @Published var offset: CGSize = .zero
    @Published var clipShape: AnyShape?

    private init() {}

    // MARK: - Presentation

    func present(image: UIImage, from frame: CGRect, clipShape: AnyShape?) {
        self.image = image
        self.sourceFrame = frame
        self.scale = 1
        self.offset = .zero
        self.clipShape = clipShape
        self.isGestureActive = true
        self.isVisible = true
    }

    /// Presents and animates the image to fill the screen, centered.
    func presentCentered(image: UIImage, from frame: CGRect, clipShape: AnyShape? = nil, screenSize: CGSize) {
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
        withAnimation(ZoomOverlayConstants.presentCenteredSpring) {
            self.scale = ZoomOverlayConstants.fullOpacityScale
            self.offset = targetOffset
        }
    }

    // MARK: - Gesture Lifecycle

    /// Called when the originating pinch gesture ends. Hands off to the overlay's
    /// own gestures, or dismisses if scale is at or below minScale.
    func commitPinchGesture() {
        isGestureActive = false
        if scale <= ZoomOverlayConstants.minScale {
            dismiss()
        } else if scale > ZoomOverlayConstants.maxScale {
            withAnimation(ZoomOverlayConstants.snapSpring) {
                scale = ZoomOverlayConstants.maxScale
            }
        }
    }

    func dismiss() {
        withAnimation(ZoomOverlayConstants.snapSpring, completionCriteria: .logicallyComplete) {
            scale = 1
            offset = .zero
        } completion: {
            self.isVisible = false
            self.image = nil
        }
    }

    /// Flings the card a short distance in the direction of `velocity`,
    /// then springs back to source position and dismisses.
    func fling(velocity: CGVector) {
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
            withAnimation(ZoomOverlayConstants.flingReturnSpring, completionCriteria: .logicallyComplete) {
                self.scale = 1
                self.offset = .zero
            } completion: {
                self.isVisible = false
                self.image = nil
            }
        }
    }

    // MARK: - Snap

    /// Snaps scale to [minScale, maxScale] if outside bounds.
    func snapScaleToBoundsIfNeeded() {
        if scale < ZoomOverlayConstants.minScale {
            withAnimation(ZoomOverlayConstants.snapSpring) {
                scale = ZoomOverlayConstants.minScale
            }
        } else if scale > ZoomOverlayConstants.maxScale {
            withAnimation(ZoomOverlayConstants.snapSpring) {
                scale = ZoomOverlayConstants.maxScale
            }
        }
    }

    /// Snaps pan offset to the allowed bounds if it's currently outside them.
    func snapPanOffsetIfNeeded(screenSize: CGSize) {
        let (boundsX, boundsY) = panBounds(screenSize: screenSize)

        var newOffset = offset
        newOffset.width = max(boundsX.min, min(boundsX.max, newOffset.width))
        newOffset.height = max(boundsY.min, min(boundsY.max, newOffset.height))

        if newOffset != offset {
            withAnimation(ZoomOverlayConstants.snapSpring) {
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
        let minDim = min(screenSize.width, screenSize.height)
        let boundsX = panBoundsForAxis(scaledImageSize: sourceFrame.width * scale, sourceCenter: sourceFrame.midX, screenSize: screenSize.width, minScreenDimension: minDim)
        let boundsY = panBoundsForAxis(scaledImageSize: sourceFrame.height * scale, sourceCenter: sourceFrame.midY, screenSize: screenSize.height, minScreenDimension: minDim)
        return (boundsX, boundsY)
    }

    private func panBoundsForAxis(
        scaledImageSize: CGFloat,
        sourceCenter: CGFloat,
        screenSize: CGFloat,
        minScreenDimension: CGFloat
    ) -> (min: CGFloat, max: CGFloat) {
        let buffer = minScreenDimension * ZoomOverlayConstants.panEdgeBufferFraction
        let centeringOffset = screenSize / 2 - sourceCenter
        let overflow = (scaledImageSize - screenSize) / 2
        if overflow <= 0 {
            return (min: centeringOffset, max: centeringOffset)
        }
        return (min: centeringOffset - overflow - buffer, max: centeringOffset + overflow + buffer)
    }
}
