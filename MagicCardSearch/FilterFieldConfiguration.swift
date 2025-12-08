//
//  FilterFieldConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

// MARK: - Filter Field Configuration

enum FilterFieldType {
    case text(placeholder: String)
    case numeric(placeholder: String, range: ClosedRange<Int>, step: Int)
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
        fieldType: .text(placeholder: "e.g. 7ED, MH3"),
        aliases: ["set", "s", "e"]
    ),
    
    "manavalue": FilterFieldConfiguration(
        displayName: "Mana Value",
        fieldType: .numeric(placeholder: "Enter mana value", range: 0...20, step: 1),
        aliases: ["manavalue", "mv", "cmc"]
    ),
    
    "power": FilterFieldConfiguration(
        displayName: "Power",
        fieldType: .numeric(placeholder: "Enter power", range: -1...20, step: 1),
        aliases: ["power", "pow"]
    ),
    
    "toughness": FilterFieldConfiguration(
        displayName: "Toughness",
        fieldType: .numeric(placeholder: "Enter toughness", range: -1...20, step: 1),
        aliases: ["toughness", "tou"]
    ),
    
    "format": FilterFieldConfiguration(
        displayName: "Format",
        fieldType: .enumeration(options: [
            "standard", "modern", "legacy", "vintage",
            "commander", "pioneer", "pauper", "historic"
        ]),
        aliases: ["format", "f", "legal"]
    ),
    
    "name": FilterFieldConfiguration(
        displayName: "Card Name",
        fieldType: .text(placeholder: "Enter card name"),
        aliases: ["name", "n"]
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
