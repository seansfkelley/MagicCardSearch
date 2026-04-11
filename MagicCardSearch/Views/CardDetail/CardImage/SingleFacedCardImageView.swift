import SwiftUI
import ScryfallKit

struct SingleFacedCardImageView: View {
    let face: CardFaceDisplayable
    let orientation: Card.Orientation
    let quality: CardImageQuality
    let cornerRadius: CGFloat
    let enableTransforms: CardImageView.FaceTransforms
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    @State private var rotation: Rotation

    init(
        face: CardFaceDisplayable,
        orientation: Card.Orientation,
        quality: CardImageQuality,
        cornerRadius: CGFloat,
        enableTransforms: CardImageView.FaceTransforms,
        enableCopyActions: Bool,
        enableZoomGestures: ZoomOverlayInitationGestures?,
        zoomGestureBasisAdjustment: CGFloat?
    ) {
        self.face = face
        self.orientation = orientation
        self.quality = quality
        self.cornerRadius = cornerRadius
        self.enableTransforms = enableTransforms
        self.enableCopyActions = enableCopyActions
        self.enableZoomGestures = enableZoomGestures
        self.zoomGestureBasisAdjustment = zoomGestureBasisAdjustment
        _rotation = State(initialValue: orientation.initialRotation(for: enableTransforms))
    }

    var body: some View {
        Group {
            if let target = orientation.allowedOtherRotation(for: enableTransforms) {
                VStack(spacing: 10) {
                    image
                    RotateButton(rotation: $rotation, nonZero: target)
                }
            } else {
                image
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: rotation)
    }

    @ViewBuilder
    private var image: some View {
        LazyCardImageView(
            face: face,
            quality: quality,
            cornerRadius: cornerRadius,
            enableCopyActions: enableCopyActions,
            enableZoomGestures: enableZoomGestures,
            zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
        )
        .rotationEffect(rotation.angle)
        .scaleEffect(rotation.scale)
    }
}

struct RotateButton: View {
    @Binding var rotation: Rotation
    let nonZero: Rotation

    var body: some View {
        Button {
            withAnimation {
                rotation = rotation == .upright ? nonZero : .upright
            }
        } label: {
            Label("Rotate", systemImage: "arrow.trianglehead.2.clockwise.rotate.90")
        }
    }
}
