import ScryfallKit

extension Card.Layout {
    var isDoubleFaced: Bool {
        switch self {
        case .transform, .meld, .modalDfc, .doubleSided, .reversibleCard, .doubleFacedToken: true
        default: false
        }
    }
}
