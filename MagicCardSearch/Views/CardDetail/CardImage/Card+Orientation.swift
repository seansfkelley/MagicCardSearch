import SwiftUI
import ScryfallKit

extension Card {
    enum Orientation: Equatable {
        enum LandscapeDirection: Equatable {
            case clockwise, counterclockwise
        }

        case portrait
        case landscape(LandscapeDirection)
        // either implies portrait default.
        case either(LandscapeDirection)
        case flip
    }
}
