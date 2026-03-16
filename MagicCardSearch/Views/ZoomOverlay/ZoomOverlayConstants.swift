import SwiftUI

enum ZoomOverlayConstants {
    // MARK: - Scale
    static let minRetainedZoomScale: CGFloat = 1.2
    static let maxNonRubberbandingZoomScale: CGFloat = 1.7
    static let minLightboxOpacity: CGFloat = 0.2
    static let maxLightboxOpacity: CGFloat = 0.8
    /// The scale at which the background reaches full opacity.
    static let fullOpacityReachedAtScaleFactor: CGFloat = 1.4

    // MARK: - Pan
    /// Rubber-band resistance for panning past the edge. Smaller = more stretch.
    static let panRubberBandCoefficient: CGFloat = 0.01
    /// Rubber-band resistance for scale past min/max. Smaller = more stretch.
    static let scaleRubberBandCoefficient: CGFloat = 1.0
    /// Pan edge buffer as a fraction of the screen's smaller dimension.
    static let panEdgeBufferFraction: CGFloat = 0.1

    // MARK: - Fling
    /// Minimum pan velocity (pt/s) required to trigger a fling dismiss.
    static let flingVelocityThreshold: CGFloat = 2000
    /// How far the card travels in the fling direction before snapping back.
    static let flingDistance: CGFloat = 350
    /// How much scale is shed during the fling throw.
    static let flingScaleReduction: CGFloat = 0.15

    // MARK: - Animations
    static let snapBackAnimation = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let presentCenteredAnimation = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let flingThrowAnimation = Animation.easeOut(duration: 0.12)
    static let flingReturnAnimation = Animation.spring(response: 0.22, dampingFraction: 0.8)
}
