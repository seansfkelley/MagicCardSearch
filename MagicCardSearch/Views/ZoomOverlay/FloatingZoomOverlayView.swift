import SwiftUI

struct FloatingZoomOverlayView: View {
    @EnvironmentObject private var manager: ZoomOverlayManager

    // Gesture state accumulators
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var scaleDelta: CGFloat = 1
    @GestureState private var rotationDelta: Angle = .zero

    var body: some View {
        ZStack {
            if manager.isVisible, let image = manager.image {
                Color.black
                    .opacity(backgroundOpacity)
                    .ignoresSafeArea()
                    .onTapGesture {
                        manager.dismiss()
                    }

                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: manager.sourceFrame.width, height: manager.sourceFrame.height)
                    .clipShape(RoundedRectangle(cornerRadius: manager.cornerRadius))
                    .scaleEffect(manager.scale * scaleDelta)
                    .rotationEffect(manager.rotation + rotationDelta)
                    .offset(
                        x: manager.offset.width + dragDelta.width,
                        y: manager.offset.height + dragDelta.height
                    )
                    .position(x: manager.sourceFrame.midX, y: manager.sourceFrame.midY)
                    .gesture(combinedGesture)
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        // Fade in background as user zooms or pans
        let zoomAmount = abs(manager.scale - 1)
        let panAmount = sqrt(pow(manager.offset.width, 2) + pow(manager.offset.height, 2)) / 200
        return min(0.6, Double(zoomAmount * 0.5 + panAmount * 0.3))
    }

    private var combinedGesture: some Gesture {
        let drag = DragGesture(minimumDistance: 0)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                manager.offset.width += value.translation.width
                manager.offset.height += value.translation.height
            }

        let magnify = MagnificationGesture()
            .updating($scaleDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                let finalScale = manager.scale * value
                if finalScale <= 1 {
                    manager.dismiss()
                } else {
                    manager.scale = finalScale
                }
            }

        let rotate = RotationGesture()
            .updating($rotationDelta) { value, state, _ in
                state = value
            }
            .onEnded { value in
                manager.rotation += value
            }

        return magnify
            .simultaneously(with: drag)
            .simultaneously(with: rotate)
    }
}
