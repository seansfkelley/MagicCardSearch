import ScryfallKit

enum SpoilersSortOrder: String, CaseIterable, Identifiable {
    case spoiled
    case rarity

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spoiled: "Spoiled Date"
        case .rarity: "Rarity"
        }
    }

    var subtitle: String {
        switch self {
        case .spoiled: "Newest First"
        case .rarity: "Rarest First"
        }
    }

    var scryfallSortMode: SortMode {
        switch self {
        case .spoiled: .spoiled
        case .rarity: .rarity
        }
    }
}
