import SwiftUI
import ScryfallKit

private extension VerticalAlignment {
    struct CenteredOnArt: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context.height * 0.33 // empirical
        }
    }

    static let centeredOnArt = VerticalAlignment(CenteredOnArt.self)
}

struct DoubleFacedCardImageView: View {
    let frontFace: CardFaceDisplayable
    let backFace: CardFaceDisplayable
    let frontFaceOrientation: Card.Orientation
    let backFaceOrientation: Card.Orientation
    let quality: CardImageQuality
    @Binding var isShowingBackFace: Bool
    let cornerRadius: CGFloat
    let enableTransforms: CardImageView.FaceTransforms
    let enableCopyActions: Bool
    let enableZoomGestures: ZoomOverlayInitationGestures?
    let zoomGestureBasisAdjustment: CGFloat?

    @State private var frontFaceRotation: Rotation
    @State private var backFaceRotation: Rotation

    init(
        frontFace: CardFaceDisplayable,
        backFace: CardFaceDisplayable,
        frontFaceOrientation: Card.Orientation,
        backFaceOrientation: Card.Orientation,
        quality: CardImageQuality,
        isShowingBackFace: Binding<Bool>,
        cornerRadius: CGFloat,
        enableTransforms: CardImageView.FaceTransforms,
        enableCopyActions: Bool,
        enableZoomGestures: ZoomOverlayInitationGestures?,
        zoomGestureBasisAdjustment: CGFloat?
    ) {
        self.frontFace = frontFace
        self.backFace = backFace
        self.frontFaceOrientation = frontFaceOrientation
        self.backFaceOrientation = backFaceOrientation
        self.quality = quality
        self._isShowingBackFace = isShowingBackFace
        self.cornerRadius = cornerRadius
        self.enableTransforms = enableTransforms
        self.enableCopyActions = enableCopyActions
        self.enableZoomGestures = enableZoomGestures
        self.zoomGestureBasisAdjustment = zoomGestureBasisAdjustment
        _frontFaceRotation = State(initialValue: frontFaceOrientation.initialRotation(for: enableTransforms))
        _backFaceRotation = State(initialValue: backFaceOrientation.initialRotation(for: enableTransforms))
    }

    private var currentScale: CGFloat {
        isShowingBackFace ? backFaceRotation.scale : frontFaceRotation.scale
    }

    private var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) {
        switch enableTransforms {
        case .none, .portrait:
            (x: 0, y: 1, z: 0)
        case .all:
            if frontFaceRotation.axis == backFaceRotation.axis {
                (x: 0, y: 1, z: 0)
            } else {
                (x: 1, y: -1, z: 0)
            }
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ZStack(alignment: Alignment(horizontal: .trailing, vertical: .centeredOnArt)) {
                ZStack {
                    LazyCardImageView(
                        face: frontFace,
                        quality: quality,
                        cornerRadius: cornerRadius,
                        enableCopyActions: enableCopyActions,
                        enableZoomGestures: enableZoomGestures,
                        zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                    )
                    .rotationEffect(frontFaceRotation.angle)
                    .scaleEffect(currentScale)
                    .opacity(isShowingBackFace ? 0 : 1)
                    .rotation3DEffect(
                        .degrees(isShowingBackFace ? 180 : 0),
                        axis: rotationAxis,
                    )

                    LazyCardImageView(
                        face: backFace,
                        quality: quality,
                        cornerRadius: cornerRadius,
                        enableCopyActions: enableCopyActions,
                        enableZoomGestures: enableZoomGestures,
                        zoomGestureBasisAdjustment: zoomGestureBasisAdjustment,
                    )
                    .rotationEffect(backFaceRotation.angle)
                    .scaleEffect(currentScale)
                    .opacity(isShowingBackFace ? 1 : 0)
                    .rotation3DEffect(
                        .degrees(isShowingBackFace ? 0 : -180),
                        axis: rotationAxis,
                    )
                }
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingBackFace)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: frontFaceRotation)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: backFaceRotation)
                .alignmentGuide(.centeredOnArt) { $0.height * 0.37 }

                if enableTransforms != .none {
                    Button {
                        isShowingBackFace.toggle()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                            .padding(8)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                    .shadow(color: .black.opacity(0.2), radius: 3, x: 0, y: 2)
                }
            }
        }

        if enableTransforms == .all {
            ZStack {
                if let target = frontFaceOrientation.allowedOtherRotation(for: .all) {
                    RotateButton(rotation: $frontFaceRotation, nonZero: target)
                        .opacity(isShowingBackFace ? 0 : 1)
                }
                if let target = backFaceOrientation.allowedOtherRotation(for: .all) {
                    RotateButton(rotation: $backFaceRotation, nonZero: target)
                        .opacity(isShowingBackFace ? 1 : 0)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isShowingBackFace)
        }
    }
}
