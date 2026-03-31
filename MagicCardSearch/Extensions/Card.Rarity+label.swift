import ScryfallKit

extension Card.Rarity {
    var label: String {
        switch self {
        case .common: "Common"
        case .uncommon: "Uncommon"
        case .rare: "Rare"
        case .mythic: "Mythic"
        case .bonus: "Bonus"
        case .special: "Special"
        }
    }
}
