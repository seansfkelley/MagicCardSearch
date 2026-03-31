import ScryfallKit

extension Game {
    var label: String {
        switch self {
        case .paper: "Paper"
        case .arena: "Arena"
        case .mtgo: "MTGO"
        case .astral: "Astral"
        case .sega: "Sega"
        }
    }
}
