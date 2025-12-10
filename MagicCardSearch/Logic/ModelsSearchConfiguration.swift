//
//  SearchConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation
import ScryfallKit

struct SearchConfiguration: Equatable, Codable {
    var uniqueMode: UniqueMode = .cards
    var sortField: SortField = .name
    var sortOrder: SortOrder = .auto
    
    static let defaultConfig = SearchConfiguration()
    
    mutating func resetToDefaults() {
        uniqueMode = .cards
        sortField = .name
        sortOrder = .auto
    }
    
    // MARK: - Enums
    
    enum UniqueMode: String, CaseIterable, Codable {
        case cards = "Cards"
        case prints = "All prints"
        case art = "Unique art"
        
        var apiValue: String {
            String(describing: self)
        }
        
        /// Convert to ScryfallKit's UniqueMode for API calls
        func toScryfallKitUniqueMode() -> ScryfallKit.UniqueMode {
            switch self {
            case .cards: return .cards
            case .prints: return .prints
            case .art: return .art
            }
        }
    }
    
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
        
        // Use the enum case name itself as the API key
        var apiValue: String {
            String(describing: self)
        }
        
        // swiftlint:disable:next cyclomatic_complexity
        func toScryfallKitSortMode() -> ScryfallKit.SortMode? {
            return switch self {
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
            }
        }
    }
    
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
        case uniqueMode, sortField, sortOrder
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
