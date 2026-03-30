import Testing
import UIKit
@testable import MagicCardSearch

// MARK: - rubberBand

struct RubberBandTests {
    @Test<[(raw: CGFloat, min: CGFloat, max: CGFloat)]>("values within bounds pass through unchanged", arguments: [
        (raw: 0.5, min: 0.0, max: 1.0),
        (raw: 1.0, min: 1.0, max: 2.0),
        (raw: 2.0, min: 1.0, max: 2.0),
        (raw: 1.5, min: 1.0, max: 2.0),
    ])
    func withinBounds(raw: CGFloat, min: CGFloat, max: CGFloat) {
        #expect(rubberBand(raw, min: min, max: max, coefficient: 1.0) == raw)
    }

    @Test("values below min are damped upward")
    func belowMin() {
        let result = rubberBand(-10.0, min: 0.0, max: 1.0, coefficient: 1.0)
        #expect(abs(result + 0.9) < 0.1)
    }

    @Test("values above max are damped downward")
    func aboveMax() {
        let result = rubberBand(11.0, min: 0.0, max: 10.0, coefficient: 1.0)
        #expect(abs(result - 10.5) < 0.1)
    }

    @Test("smaller coefficient allows more stretch past boundary")
    func smallerCoefficientMoreStretch() {
        let tightResult = rubberBand(20.0, min: 0.0, max: 10.0, coefficient: 1.0)
        let looseResult = rubberBand(20.0, min: 0.0, max: 10.0, coefficient: 0.01)
        #expect(looseResult > tightResult)
    }

    @Test("result is symmetric around bounds")
    func symmetric() {
        let below = rubberBand(-5.0, min: 0.0, max: 10.0, coefficient: 1.0)
        let above = rubberBand(15.0, min: 0.0, max: 10.0, coefficient: 1.0)
        let belowExcess = 0.0 - below
        let aboveExcess = above - 10.0
        #expect(abs(belowExcess - aboveExcess) < 0.001)
    }

    @Test("exact boundary values pass through unchanged")
    func exactBoundary() {
        #expect(rubberBand(1.0, min: 1.0, max: 2.0, coefficient: 1.0) == 1.0)
        #expect(rubberBand(2.0, min: 1.0, max: 2.0, coefficient: 1.0) == 2.0)
    }
}

// MARK: - ZoomOverlayState

@MainActor
struct ZoomOverlayStateTests {
    let state = ZoomOverlayState(yesThisIsTheSingletonOrTestCode: true, enableAnimations: false)
    let image = UIImage()
    let frame = CGRect(x: 10, y: 20, width: 100, height: 150)
    let frameCenter = CGPoint(x: 60, y: 95)
    let offFrameCenter = CGPoint(x: 300, y: 600)
    let screenSize = CGSize(width: 390, height: 844)

    // MARK: - show

    @Test("show(.continuingGesture) sets isVisible and isInitiatingGesture")
    func showContinuingGesture() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        #expect(state.isVisible == true)
        #expect(state.isInitiatingGesture == true)
        #expect(state.image === image)
        #expect(state.sourceFrame == frame)
        #expect(state.screenSize == screenSize)
        #expect(state.scale == 1)
        #expect(state.translation == .zero)
    }

    @Test("show(.autoZoomTo) sets isVisible and clears isInitiatingGesture")
    func showAutoZoomTo() {
        let targetSize = CGSize(width: 50, height: 100)
        state.show(image: image, in: frame, screenSize: screenSize, with: .autoZoomTo(targetSize))
        #expect(state.isVisible == true)
        #expect(state.isInitiatingGesture == false)
        #expect(state.image === image)
        #expect(state.sourceFrame == frame)
        #expect(state.screenSize == screenSize)
        #expect(state.scale == ZoomOverlayConstants.maxOpacityReachedAtScaleFactor)
        #expect(state.translation == targetSize)
    }

    @Test("show resets scale and translation")
    func showResetsTransform() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.5, aroundCentroid: offFrameCenter)
        #expect(state.scale != 1)
        #expect(state.translation != .zero)
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        #expect(state.scale == 1)
        #expect(state.translation == .zero)
    }

    // MARK: - applyScale

    @Test("applyScale within normal range updates scale")
    func applyScaleNormalRange() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.4, aroundCentroid: frameCenter)
        #expect(state.scale == 1.4)
        #expect(state.translation == .zero)
    }

    @Test("applyScale below min rubber-bands (result above raw but below min)")
    func applyScaleBelowMin() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(0.5, aroundCentroid: frameCenter)
        #expect(abs(state.scale - 0.667) < 0.05)
        #expect(state.translation == .zero)
    }

    @Test("applyScale above max rubber-bands (result below raw but above max)")
    func applyScaleAboveMax() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(3.0, aroundCentroid: frameCenter)
        #expect(abs(state.scale - 2.3) < 0.1)
        #expect(state.translation == .zero)
    }

    @Test("applyScale adjusts translation when centroid is off-center")
    func applyScaleAdjustsTranslation() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.5, aroundCentroid: offFrameCenter)
        #expect(state.translation != .zero)
    }

    // MARK: - applyTranslation(rawRelative:)

    @Test("applyTranslation(rawRelative:) accumulates translation")
    func applyTranslationRawRelative() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyTranslation(rawRelative: CGPoint(x: 10, y: 20))
        #expect(state.translation.width == 10)
        #expect(state.translation.height == 20)
        state.applyTranslation(rawRelative: CGPoint(x: -5, y: 8))
        #expect(state.translation.width == 5)
        #expect(state.translation.height == 28)
    }

    // MARK: - applyTranslation(rubberBandedFromAbsolute:)

    @Test("applyTranslation(rubberBandedFromAbsolute:) passes through in-bounds translation unchanged")
    func applyTranslationRubberBandedInBounds() {
        // Use a frame centered on screen so the centering offset is zero and
        // the in-bounds range at scale 1 is (0,0)–(0,0) exactly, making zero a known in-bounds value.
        let centeredFrame = CGRect(
            x: (screenSize.width - frame.width) / 2,
            y: (screenSize.height - frame.height) / 2,
            width: frame.width,
            height: frame.height,
        )
        state.show(image: image, in: centeredFrame, screenSize: screenSize, with: .continuingGesture)
        // At scale 1 with the frame centered, the centering offset is zero and
        // the image exactly fills its own extent — translation (0,0) is in-bounds.
        state.applyTranslation(rubberBandedFromAbsolute: .zero)
        #expect(state.translation == .zero)
    }

    @Test("applyTranslation(rubberBandedFromAbsolute:) rubber-bands extreme out-of-bounds translation")
    func applyTranslationRubberBandedOutOfBounds() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.3, aroundCentroid: CGPoint(x: frame.midX, y: frame.midY))
        let extreme = CGSize(width: 5000, height: 5000)
        state.applyTranslation(rubberBandedFromAbsolute: extreme)
        // Subtracted values were computed empirically and given extreme epsilon.
        #expect(abs(state.translation.width - 232) < 1)
        #expect(abs(state.translation.height - 424) < 1)
    }

    // MARK: - zoomBasisAdjustment

    @Test("zoomBasisAdjustment > 1.0 produces thresholds larger than the base constants")
    func zoomBasisAdjustmentScalesThresholds() {
        state.show(image: image, in: frame, screenSize: screenSize, zoomBasisAdjustment: 2.0, with: .continuingGesture)
        #expect(state.minRetainedZoomScale > ZoomOverlayConstants.minRetainedZoomScale)
        #expect(state.maxNonRubberBandingZoomScale > ZoomOverlayConstants.maxNonRubberBandingZoomScale)
        #expect(state.maxOpacityReachedAtScaleFactor > ZoomOverlayConstants.maxOpacityReachedAtScaleFactor)
    }

    @Test("zoomBasisAdjustment below 1.0 clamps to the base constants", arguments: [0.5, -1.0] as [CGFloat])
    func zoomBasisAdjustmentClampsBelowOne(adjustment: CGFloat) {
        state.show(image: image, in: frame, screenSize: screenSize, zoomBasisAdjustment: adjustment, with: .continuingGesture)
        #expect(state.minRetainedZoomScale == ZoomOverlayConstants.minRetainedZoomScale)
        #expect(state.maxNonRubberBandingZoomScale == ZoomOverlayConstants.maxNonRubberBandingZoomScale)
        #expect(state.maxOpacityReachedAtScaleFactor == ZoomOverlayConstants.maxOpacityReachedAtScaleFactor)
    }

    @Test("finishedScaling dismisses when scale is between base min and adjusted min")
    func zoomBasisAdjustmentFinishedScalingDismissesBeforeAdjustedMin() {
        // With adjustment=2.0 the adjusted min is 1.4; a scale of 1.3 is above the base min (1.2)
        // but below the adjusted min, so the overlay should dismiss.
        state.show(image: image, in: frame, screenSize: screenSize, zoomBasisAdjustment: 2.0, with: .continuingGesture)
        state.applyScale(1.3, aroundCentroid: frameCenter)
        #expect(state.scale < state.minRetainedZoomScale)
        state.finishedScaling()
        #expect(state.isVisible == false)
    }

    // MARK: - finishedScaling

    @Test("finishedScaling at scale above min keeps overlay visible")
    func finishedScalingAboveMin() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(ZoomOverlayConstants.minRetainedZoomScale + 0.1, aroundCentroid: frameCenter)
        state.finishedScaling()
        #expect(state.isVisible == true)
    }

    @Test("finishedScaling at rubber-banded scale below min calls dismiss")
    func finishedScalingBelowMin() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(0.5, aroundCentroid: frameCenter)
        #expect(state.scale < ZoomOverlayConstants.minRetainedZoomScale)
        state.finishedScaling()
        #expect(state.isVisible == false)
        #expect(state.image == nil)
    }

    // MARK: - initiatingGestureFinished

    @Test("initiatingGestureFinished clears isInitiatingGesture")
    func initiatingGestureFinishedClearsFlag() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        #expect(state.isInitiatingGesture == true)
        state.applyScale(1.5, aroundCentroid: CGPoint(x: frame.midX, y: frame.midY))
        state.initiatingGestureFinished()
        #expect(state.isInitiatingGesture == false)
    }

    @Test("initiatingGestureFinished when not in initiating gesture is a no-op")
    func initiatingGestureFinishedNoOp() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.5, aroundCentroid: frameCenter)
        state.initiatingGestureFinished()
        let scaleAfterFirst = state.scale
        state.initiatingGestureFinished()
        #expect(state.scale == scaleAfterFirst)
    }

    @Test("initiatingGestureFinished with scale below min triggers dismiss")
    func initiatingGestureFinishedBelowMinDismisses() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(0.5, aroundCentroid: frameCenter)
        state.initiatingGestureFinished()
        #expect(state.isVisible == false)
    }

    // MARK: - dismiss

    @Test("dismiss resets state and hides overlay")
    func dismissResetsState() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.4, aroundCentroid: frameCenter)
        #expect(state.isVisible == true)
        state.dismiss()
        #expect(state.isVisible == false)
    }

    @Test("dismiss(withFling:) with zero velocity still dismisses")
    func dismissWithFlingZeroVelocity() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.4, aroundCentroid: frameCenter)
        #expect(state.isVisible == true)
        state.dismiss(withFling: CGVector(dx: 0, dy: 0))
        #expect(state.isVisible == false)
    }

    @Test("dismiss(withFling:) with nonzero velocity dismisses overlay")
    func dismissWithFlingNonzeroVelocity() {
        state.show(image: image, in: frame, screenSize: screenSize, with: .continuingGesture)
        state.applyScale(1.4, aroundCentroid: frameCenter)
        #expect(state.isVisible == true)
        state.dismiss(withFling: CGVector(dx: 1000, dy: 500))
        #expect(state.isVisible == false)
    }
}
