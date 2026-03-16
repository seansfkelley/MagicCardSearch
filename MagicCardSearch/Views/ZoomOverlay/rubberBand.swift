import Foundation

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
