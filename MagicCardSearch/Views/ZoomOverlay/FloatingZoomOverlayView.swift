import SwiftUI

private let minScale: CGFloat = 1.0
private let maxScale: CGFloat = 2.0

private func rubberBand(_ raw: CGFloat, min: CGFloat, max: CGFloat, coefficient: CGFloat = 0.15) -> CGFloat {
    if raw < min {
        let excess = min - raw
        return min - excess / (1 + excess * coefficient)
    } else if raw > max {
        let excess = raw - max
        return max + excess / (1 + excess * coefficient)
    }
    return raw
}

struct FloatingZoomOverlayView: View {
    @EnvironmentObject private var manager: ZoomOverlayManager

    // Gesture state accumulators
    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var scaleDelta: CGFloat = 1

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
                    .scaleEffect(rubberBand(manager.scale * scaleDelta, min: minScale, max: maxScale))
                    .offset(
                        x: manager.offset.width + dragDelta.width,
                        y: manager.offset.height + dragDelta.height
                    )
                    .position(x: manager.sourceFrame.midX, y: manager.sourceFrame.midY)
                    .gesture(manager.isGestureActive ? nil : combinedGesture)
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundOpacity: Double {
        let liveScale = Double(rubberBand(manager.scale * scaleDelta, min: minScale, max: maxScale))
        let fullOpacityScaleFactor = 1.5
        let t = (liveScale - 1.0) / (fullOpacityScaleFactor - 1.0)
        return max(0, min(1, t))
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
                // Rubber-band the delta so visual feedback resists past bounds.
                let raw = manager.scale * value
                let clamped = rubberBand(raw, min: minScale, max: maxScale)
                state = clamped / manager.scale
            }
            .onEnded { value in
                let rawScale = manager.scale * value
                if rawScale <= minScale {
                    manager.dismiss()
                } else {
                    manager.scale = rubberBand(rawScale, min: minScale, max: maxScale)
                    manager.snapToBoundsIfNeeded()
                }
            }

        return magnify
            .simultaneously(with: drag)
    }
}
