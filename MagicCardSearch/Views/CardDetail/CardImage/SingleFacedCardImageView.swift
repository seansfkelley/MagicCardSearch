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
                VStack(spacing: 20) {
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
            imageRotation: rotation,
        )
        .rotationEffect(rotation.angle)
        .scaleEffect(rotation.scale)
    }
}
