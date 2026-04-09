import Foundation
import ScryfallKit

struct SearchConfiguration: Equatable, Codable, CustomStringConvertible {
    var uniqueMode: UniqueMode = .cards
    var sortField: SortField = .name
    var sortOrder: SortOrder = .auto
    var preferredPrint: PreferredPrint = .default
    var automaticallyIncludeExtras = true
    var showSortLabels = true

    public var description: String {
        "uniqueMode: \(uniqueMode.apiValue), sortField: \(sortField.apiValue), sortOrder: \(sortOrder.apiValue), preferredPrint: \(preferredPrint.apiValue), automaticallyIncludeExtras: \(automaticallyIncludeExtras), showSortLabels: \(showSortLabels)"
    }

    // MARK: - Enums

    // Cases ordered by how they appear in the Scryfall UI.
    enum UniqueMode: String, CaseIterable, Codable {
        case cards = "Cards"
        case prints = "All prints"
        case art = "Unique art"
        
        var apiValue: String {
            String(describing: self)
        }
        
        func toScryfallKitUniqueMode() -> ScryfallKit.UniqueMode {
            switch self {
            case .cards: .cards
            case .prints: .prints
            case .art: .art
            }
        }
    }

    enum PreferredPrint: String, CaseIterable, Codable {
        case newest = "Newest"
        case oldest = "Oldest"
        case promo = "Promo"
        case `default` = "Default Frame"
        case nondefault = "Non-default Frame"
        case universesbeyond = "Universes Beyond"
        case notuniversesbeyond = "Non-Universes Beyond"
        // swiftlint:disable identifier_name
        case usd_low = "Cheapest (USD)"
        case usd_high = "Most Expensive (USD)"
        case eur_low = "Cheapest (EUR)"
        case eur_high = "Most Expensive (EUR)"
        case tix_low = "Cheapest (TIX)"
        case tix_high = "Most Expensive (TIX)"
        // swiftlint:enable identifier_name

        var apiValue: String {
            // Would prefer to have these be e.g. `usd-low` but the compiler won't allow that even with backticks.
            String(describing: self).replacingOccurrences(of: "_", with: "-")
        }

        // Because this can clutter up the main query string instead of just the URL parameters, try
        // to avoid including it unless we need to. This makes shared URLs reflect what you actually
        // wrote more often.
        func toStringFilter() -> String? {
            switch self {
            case .default: nil
            default: "prefer:\(self.apiValue)"
            }
        }
    }

    // Cases ordered by how they appear in the Scryfall UI.
    enum SortField: String, CaseIterable, Codable {
        case name = "Name"
        case released = "Release Date"
        case set = "Set/Number"
        case rarity = "Rarity"
        case color = "Color"
        case usd = "Price: USD"
        case tix = "Price: TIX"
        case eur = "Price: EUR"
        case cmc = "Mana Value"
        case power = "Power"
        case toughness = "Toughness"
        case artist = "Artist Name"
        case edhrec = "EDHREC Rank"
        case spoiled = "Spoiler Date"

        var apiValue: String {
            String(describing: self)
        }

        static func fromApiValue(_ value: String) -> SortField? {
            allCases.first { $0.apiValue == value }
        }

        // This is the dumbest function.
        // swiftlint:disable:next cyclomatic_complexity
        func toScryfallKitSortMode() -> ScryfallKit.SortMode? {
            switch self {
            case .name: .name
            case .released: .released
            case .set: .set
            case .rarity: .rarity
            case .color: .color
            case .usd: .usd
            case .tix: .tix
            case .eur: .eur
            case .cmc: .cmc
            case .power: .power
            case .toughness: .toughness
            case .artist: .artist
            case .edhrec: .edhrec
            case .spoiled: .spoiled
            }
        }
    }

    // Cases ordered by how they appear in the Scryfall UI.
    enum SortOrder: String, CaseIterable, Codable {
        case auto = "Auto"
        case ascending = "Ascending"
        case descending = "Descending"
        
        var apiValue: String {
            switch self {
            case .auto: return "auto"
            case .ascending: return "asc"
            case .descending: return "desc"
            }
        }
        
        /// Convert to ScryfallKit's SortDirection for API calls
        func toScryfallKitSortDirection() -> ScryfallKit.SortDirection {
            switch self {
            case .auto: return .auto
            case .ascending: return .asc
            case .descending: return .desc
            }
        }
    }
    
    // MARK: - Persistence

    private enum CodingKeys: String, CodingKey {
        case uniqueMode, sortField, sortOrder, preferredPrint, automaticallyIncludeExtras, showSortLabels
    }

    // Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "searchConfiguration")
        }
    }

    // Load from UserDefaults
    static func load() -> SearchConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "searchConfiguration"),
              let config = try? JSONDecoder().decode(SearchConfiguration.self, from: data) else {
            return SearchConfiguration() // Return default if not found
        }
        return config
    }
}

extension SearchConfiguration {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uniqueMode = try container.decode(UniqueMode.self, forKey: .uniqueMode)
        sortField = try container.decode(SortField.self, forKey: .sortField)
        sortOrder = try container.decode(SortOrder.self, forKey: .sortOrder)
        preferredPrint = try container.decode(PreferredPrint.self, forKey: .preferredPrint)
        automaticallyIncludeExtras = try container.decode(Bool.self, forKey: .automaticallyIncludeExtras)
        showSortLabels = try container.decodeIfPresent(Bool.self, forKey: .showSortLabels) ?? true
    }
}
