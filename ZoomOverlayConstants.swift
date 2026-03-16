import SwiftUI

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
    }
    return raw
}

enum ZoomOverlayConstants {
    // MARK: - Scale
    static let minScale: CGFloat = 1.2
    static let maxScale: CGFloat = 1.7
    /// The scale at which the background reaches full opacity.
    static let fullOpacityScale: CGFloat = 1.4
    static let minOpacity: CGFloat = 0.2
    static let fullOpacity: CGFloat = 0.8

    // MARK: - Pan
    /// Rubber-band resistance for panning past the edge. Smaller = more stretch.
    static let panRubberBandCoefficient: CGFloat = 0.008
    /// Rubber-band resistance for scale past min/max. Smaller = more stretch.
    static let scaleRubberBandCoefficient: CGFloat = 0.15
    /// Pan edge buffer as a fraction of the screen's smaller dimension.
    static let panEdgeBufferFraction: CGFloat = 0.1

    // MARK: - Fling
    /// Minimum pan velocity (pt/s) required to trigger a fling dismiss.
    static let flingVelocityThreshold: CGFloat = 1700
    /// How far the card travels in the fling direction before snapping back.
    static let flingDistance: CGFloat = 250
    /// How much scale is shed during the fling throw.
    static let flingScaleReduction: CGFloat = 0.15

    // MARK: - Animations
    static let snapSpring = Animation.spring(response: 0.3, dampingFraction: 0.8)
    static let presentCenteredSpring = Animation.spring(response: 0.35, dampingFraction: 0.8)
    static let flingThrowAnimation = Animation.easeOut(duration: 0.12)
    static let flingReturnSpring = Animation.spring(response: 0.22, dampingFraction: 0.8)
}
