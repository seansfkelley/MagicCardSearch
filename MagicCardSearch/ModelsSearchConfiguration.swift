//
//  SearchConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

struct SearchConfiguration: Equatable, Codable {
    var displayMode: DisplayMode = .cards
    var sortField: SortField = .name
    var sortOrder: SortOrder = .auto
    
    // Default configuration for comparison
    static let defaultConfig = SearchConfiguration()
    
    // Count how many settings differ from default
    var nonDefaultCount: Int {
        var count = 0
        if displayMode != SearchConfiguration.defaultConfig.displayMode { count += 1 }
        if sortField != SearchConfiguration.defaultConfig.sortField { count += 1 }
        if sortOrder != SearchConfiguration.defaultConfig.sortOrder { count += 1 }
        return count
    }
    
    // Reset to defaults
    mutating func resetToDefaults() {
        displayMode = .cards
        sortField = .name
        sortOrder = .auto
    }
    
    // MARK: - Enums
    
    enum DisplayMode: String, CaseIterable, Codable {
        case cards = "Cards"
        case allPrints = "All Prints"
        case uniqueArt = "Unique Art"
        
        var apiValue: String {
            switch self {
            case .cards: return "cards"
            case .allPrints: return "prints"
            case .uniqueArt: return "art"
            }
        }
    }
    
    enum SortField: String, CaseIterable, Codable {
        case name = "Name"
        case power = "Power"
        case toughness = "Toughness"
        
        var apiValue: String {
            switch self {
            case .name: return "name"
            case .power: return "power"
            case .toughness: return "toughness"
            }
        }
        
        // Constant mapping for extensibility
        static let apiFieldNames: [SortField: String] = [
            .name: "name",
            .power: "power",
            .toughness: "toughness"
        ]
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
    }
    
    // MARK: - Persistence
    
    private enum CodingKeys: String, CodingKey {
        case displayMode, sortField, sortOrder
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
