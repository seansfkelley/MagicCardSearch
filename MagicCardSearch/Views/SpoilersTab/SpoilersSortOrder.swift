import ScryfallKit

enum SpoilersSortOrder: String, CaseIterable, Identifiable {
    case spoiled
    case rarity
    case number

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .spoiled: "Spoiled Date"
        case .rarity: "Rarity"
        case .number: "Collector Number"
        }
    }

    var subtitle: String {
        switch self {
        case .spoiled: "Newest First"
        case .rarity: "Rarest First"
        case .number: "Ascending"
        }
    }

    var scryfallSortMode: SortMode {
        switch self {
        case .spoiled: .spoiled
        case .rarity: .rarity
        case .number: .set
        }
    }

    var scryfallSortDirection: SortDirection {
        switch self {
        case .spoiled: .desc
        case .rarity: .desc
        case .number: .asc
        }
    }
}
