import SwiftUI
import ScryfallKit

enum Rotation {
    enum Axis {
        case horizontal, vertical
    }

    case upright, clockwise, counterclockwise, upsideDown

    var angle: Angle {
        switch self {
        case .upright: .degrees(0)
        case .clockwise: .degrees(90)
        case .counterclockwise: .degrees(-90)
        case .upsideDown: .degrees(180)
        }
    }

    var scale: CGFloat {
        switch self {
        case .upright, .upsideDown: 1
        case .clockwise, .counterclockwise: Card.aspectRatio
        }
    }

    var axis: Axis {
        switch self {
        case .upright, .upsideDown: .vertical
        case .clockwise, .counterclockwise: .horizontal
        }
    }
}

extension Card.Orientation {
    func allowedOtherRotation(for enableTransforms: CardImageView.FaceTransforms) -> Rotation? {
        switch self {
        case .portrait:
            nil
        case .landscape(let direction), .either(let direction):
            enableTransforms == .all ? direction.rotation : nil
        case .flip:
            (enableTransforms == .portrait || enableTransforms == .all) ? .upsideDown : nil
        }
    }
}

extension Card.Orientation.LandscapeDirection {
    var rotation: Rotation {
        switch self {
        case .clockwise: .clockwise
        case .counterclockwise: .counterclockwise
        }
    }
}
