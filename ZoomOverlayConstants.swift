import Foundation

enum ZoomOverlayConstants {
    static let minScale: CGFloat = 1.2
    static let maxScale: CGFloat = 1.7
    /// The scale at which the background reaches full black.
    static let fullOpacityScale: CGFloat = 1.4
    /// Minimum pan velocity (pt/s) required to trigger a fling dismiss.
    static let flingVelocityThreshold: CGFloat = 1700
    /// How far the card travels in the fling direction before snapping back.
    static let flingDistance: CGFloat = 250
}
