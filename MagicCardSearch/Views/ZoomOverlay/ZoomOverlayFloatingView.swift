import SwiftUI

struct ZoomOverlayFloatingView: View {
    @ObservedObject private var state = ZoomOverlayState.shared

    var body: some View {
        ZStack {
            if state.isVisible, let image = state.image {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()

                Image(uiImage: image)
                    .resizable()
                    .frame(width: state.sourceFrame.width, height: state.sourceFrame.height)
                    .if(state.clipShape) { $0.clipShape($1) }
                    .scaleEffect(state.scale)
                    .offset(state.translation)
                    .position(x: state.sourceFrame.midX, y: state.sourceFrame.midY)
                    .allowsHitTesting(false)

                if !state.isInitiatingGesture {
                    ZoomOverlayFloatingGestureView()
                        .ignoresSafeArea()
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        // swiftlint:disable:next identifier_name
        let t = (Double(state.scale) - 1.0) / (Double(state.maxOpacityReachedAtScaleFactor) - 1.0)
        return UnitCurve.easeOut.value(at: max(0, min(1, t))) * ZoomOverlayConstants.maxLightboxOpacity
    }
}
