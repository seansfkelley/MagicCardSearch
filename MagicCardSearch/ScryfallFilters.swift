//
//  FilterFieldConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

// MARK: - Filter Field Configuration

enum FilterFieldType {
    // TODO: Consider regex that warns, but doesn't prevent, using a given filter.
    case text
    case numeric(range: ClosedRange<Int>, step: Int)
    case enumeration(options: [String])
}

struct FilterFieldConfiguration {
    let displayName: String
    let fieldType: FilterFieldType
    let aliases: Set<String>
}

// MARK: - Configuration Dictionary

let filterFieldConfigurations: [String: FilterFieldConfiguration] = [
    "set": FilterFieldConfiguration(
        displayName: "Set Code",
        fieldType: .text,
        aliases: ["set", "s", "e"]
    ),
    
    "manavalue": FilterFieldConfiguration(
        displayName: "Mana Value",
        fieldType: .numeric(range: 0...20, step: 1),
        aliases: ["manavalue", "mv", "cmc"]
    ),
    
    "power": FilterFieldConfiguration(
        displayName: "Power",
        fieldType: .numeric(range: -1...20, step: 1),
        aliases: ["power", "pow"]
    ),
    
    "toughness": FilterFieldConfiguration(
        displayName: "Toughness",
        fieldType: .numeric(range: -1...20, step: 1),
        aliases: ["toughness", "tou"]
    ),
    
    "format": FilterFieldConfiguration(
        displayName: "Format",
        fieldType: .enumeration(options: [
            "Standard", "Modern", "Legacy", "Vintage",
            "Commander", "Pioneer", "Pauper", "Historic"
        ]),
        aliases: ["format", "f", "legal"]
    ),
    
    "name": FilterFieldConfiguration(
        displayName: "Card Name",
        fieldType: .text,
        aliases: ["name", "n"]
    ),
    
    "oracle": FilterFieldConfiguration(
        displayName: "Oracle Text",
        fieldType: .text,
        aliases: ["oracle", "o"]
    ),
    
    "function": FilterFieldConfiguration(
        displayName: "Oracle Tags",
        fieldType: .text,
        aliases: ["function", "otag"]
    ),
    
    "type": FilterFieldConfiguration(
        displayName: "Type Line",
        fieldType: .text,
        aliases: ["type", "t"]
    ),
    
    "color": FilterFieldConfiguration(
        displayName: "Color",
        fieldType: .text,
        aliases: ["color", "c"]
    ),
    
    "coloridentity": FilterFieldConfiguration(
        displayName: "Color Identity",
        fieldType: .text,
        aliases: ["coloridentity", "id", "identity"]
    ),
    
    "rarity": FilterFieldConfiguration(
        displayName: "Rarity",
        fieldType: .enumeration(options: [
            "Common", "Uncommon", "Rare", "Mythic", "Special", "Bonus"
        ]),
        aliases: ["rarity", "r"]
    ),
    
    "artist": FilterFieldConfiguration(
        displayName: "Artist",
        fieldType: .text,
        aliases: ["artist", "a"]
    ),
    
    "flavor": FilterFieldConfiguration(
        displayName: "Flavor Text",
        fieldType: .text,
        aliases: ["flavor", "ft"]
    )
]

// MARK: - Configuration Lookup

func configurationForKey(_ key: String) -> FilterFieldConfiguration? {
    let lowercasedKey = key.lowercased()
    
    if let config = filterFieldConfigurations[lowercasedKey] {
        return config
    }

    for (_, config) in filterFieldConfigurations {
        if config.aliases.contains(lowercasedKey) {
            return config
        }
    }
    
    return nil
}

func canonicalKey(for key: String) -> String {
    let lowercasedKey = key.lowercased()
    
    if filterFieldConfigurations[lowercasedKey] != nil {
        return lowercasedKey
    }
    
    for (primaryKey, config) in filterFieldConfigurations {
        if config.aliases.contains(lowercasedKey) {
            return primaryKey
        }
    }
    
    return lowercasedKey
}
