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
                    .aspectRatio(contentMode: .fit)
                    .frame(width: state.sourceFrame.width, height: state.sourceFrame.height)
                    .if(state.clipShape != nil) { $0.clipShape(state.clipShape!) }
                    .scaleEffect(state.scale)
                    .offset(x: state.offset.width, y: state.offset.height)
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
        let t = (Double(state.scale) - 1.0) / (ZoomOverlayConstants.maxOpacityReachedAtScaleFactor - 1.0)
        return UnitCurve.easeOut.value(at: max(0, min(1, t))) * ZoomOverlayConstants.maxLightboxOpacity
    }
}
