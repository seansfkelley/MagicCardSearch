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
    // MARK: Card Names and Text
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
    
    "flavor": FilterFieldConfiguration(
        displayName: "Flavor Text",
        fieldType: .text,
        aliases: ["flavor", "ft"]
    ),
    
    "watermark": FilterFieldConfiguration(
        displayName: "Watermark",
        fieldType: .text,
        aliases: ["watermark", "wm"]
    ),
    
    // MARK: Colors and Identity
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
    
    "produces": FilterFieldConfiguration(
        displayName: "Mana Produced",
        fieldType: .text,
        aliases: ["produces", "prod"]
    ),
    
    // MARK: Mana and Costs
    "manavalue": FilterFieldConfiguration(
        displayName: "Mana Value",
        fieldType: .numeric(range: 0...20, step: 1),
        aliases: ["manavalue", "mv", "cmc"]
    ),
    
    "mana": FilterFieldConfiguration(
        displayName: "Mana Cost",
        fieldType: .text,
        aliases: ["mana", "m"]
    ),
    
    "devotion": FilterFieldConfiguration(
        displayName: "Devotion (Colored Pips)",
        fieldType: .numeric(range: 0...20, step: 1),
        aliases: ["devotion"]
    ),
    
    // MARK: Power/Toughness/Loyalty
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
    
    "loyalty": FilterFieldConfiguration(
        displayName: "Loyalty",
        fieldType: .numeric(range: 0...20, step: 1),
        aliases: ["loyalty", "loy"]
    ),
    
    // MARK: Set Information
    "set": FilterFieldConfiguration(
        displayName: "Set Code",
        fieldType: .text,
        aliases: ["set", "s", "e"]
    ),
    
    "block": FilterFieldConfiguration(
        displayName: "Block",
        fieldType: .text,
        aliases: ["block", "b"]
    ),
    
    "year": FilterFieldConfiguration(
        displayName: "Year",
        fieldType: .numeric(range: 1993...2030, step: 1),
        aliases: ["year"]
    ),
    
    // MARK: Rarity and Collector Info
    "rarity": FilterFieldConfiguration(
        displayName: "Rarity",
        fieldType: .enumeration(options: [
            "common", "uncommon", "rare", "mythic", "special", "bonus"
        ]),
        aliases: ["rarity", "r"]
    ),
    
    "number": FilterFieldConfiguration(
        displayName: "Collector Number",
        fieldType: .text,
        aliases: ["number", "cn"]
    ),
    
    // MARK: Artist and Creative
    "artist": FilterFieldConfiguration(
        displayName: "Artist",
        fieldType: .text,
        aliases: ["artist", "a"]
    ),
    
    "border": FilterFieldConfiguration(
        displayName: "Border Color",
        fieldType: .enumeration(options: [
            "black", "white", "borderless", "silver", "gold"
        ]),
        aliases: ["border"]
    ),
    
    "frame": FilterFieldConfiguration(
        displayName: "Frame Version",
        fieldType: .enumeration(options: [
            "1993", "1997", "2003", "2015", "future"
        ]),
        aliases: ["frame"]
    ),
    
    // MARK: Formats (Complete List)
    "format": FilterFieldConfiguration(
        displayName: "Format",
        fieldType: .enumeration(options: [
            "standard", "future", "historic", "timeless", "gladiator", "pioneer",
            "explorer", "modern", "legacy", "vintage", "pauper", "penny",
            "commander", "oathbreaker", "brawl", "standardbrawl", "alchemy",
            "paupercommander", "duel", "oldschool", "premodern", "predh"
        ]),
        aliases: ["format", "f", "legal"]
    ),
    
    "banned": FilterFieldConfiguration(
        displayName: "Banned In Format",
        fieldType: .enumeration(options: [
            "standard", "future", "historic", "timeless", "gladiator", "pioneer",
            "explorer", "modern", "legacy", "vintage", "pauper", "penny",
            "commander", "oathbreaker", "brawl", "standardbrawl", "alchemy",
            "paupercommander", "duel", "oldschool", "premodern", "predh"
        ]),
        aliases: ["banned"]
    ),
    
    "restricted": FilterFieldConfiguration(
        displayName: "Restricted In Format",
        fieldType: .enumeration(options: [
            "standard", "future", "historic", "timeless", "gladiator", "pioneer",
            "explorer", "modern", "legacy", "vintage", "pauper", "penny",
            "commander", "oathbreaker", "brawl", "standardbrawl", "alchemy",
            "paupercommander", "duel", "oldschool", "premodern", "predh"
        ]),
        aliases: ["restricted"]
    ),
    
    // MARK: Card Properties
    "is": FilterFieldConfiguration(
        displayName: "Card Properties",
        fieldType: .enumeration(options: [
            "vanilla", "funny", "reprint", "new", "digital", "spotlight",
            "masterpiece", "unique", "colorshifted", "companion", "booster",
            "planeswalker", "creature", "spell", "permanent", "historic",
            "modal", "split", "flip", "transform", "meld", "leveler",
            "commander", "fetchland", "shockland", "triland", "bicycleland",
            "checkland", "dual", "fastland", "filterland", "gainland",
            "painland", "scryland", "shadowland", "slowland", "storageland",
            "tangoland", "canopyland", "bounceland", "manland", "reserved",
            "full", "hires", "rebalanced", "promo", "spotlight"
        ]),
        aliases: ["is"]
    ),
    
    "not": FilterFieldConfiguration(
        displayName: "Not (Card Properties)",
        fieldType: .enumeration(options: [
            "vanilla", "funny", "reprint", "new", "digital", "spotlight",
            "masterpiece", "unique", "colorshifted", "companion", "booster",
            "planeswalker", "creature", "spell", "permanent", "historic",
            "modal", "split", "flip", "transform", "meld", "leveler",
            "commander", "fetchland", "shockland", "triland", "bicycleland",
            "checkland", "dual", "fastland", "filterland", "gainland",
            "painland", "scryland", "shadowland", "slowland", "storageland",
            "tangoland", "canopyland", "bounceland", "manland", "reserved",
            "full", "hires", "rebalanced", "promo", "spotlight"
        ]),
        aliases: ["not"]
    ),
    
    // MARK: Game and Play Modes
    "game": FilterFieldConfiguration(
        displayName: "Game Type",
        fieldType: .enumeration(options: [
            "paper", "arena", "mtgo"
        ]),
        aliases: ["game"]
    ),
    
    // MARK: Language
    "language": FilterFieldConfiguration(
        displayName: "Language",
        fieldType: .enumeration(options: [
            "en", "es", "fr", "de", "it", "pt", "ja", "ko", "ru",
            "zhs", "zht", "he", "la", "grc", "ar", "sa", "ph"
        ]),
        aliases: ["language", "lang", "l"]
    ),
    
    // MARK: Cube and Collection
    "cube": FilterFieldConfiguration(
        displayName: "Cube Name",
        fieldType: .text,
        aliases: ["cube"]
    ),
    
    "in": FilterFieldConfiguration(
        displayName: "In (Collection/Cube)",
        fieldType: .text,
        aliases: ["in"]
    ),
    
    // MARK: Prices
    "usd": FilterFieldConfiguration(
        displayName: "USD Price",
        fieldType: .text,
        aliases: ["usd"]
    ),
    
    "eur": FilterFieldConfiguration(
        displayName: "EUR Price",
        fieldType: .text,
        aliases: ["eur"]
    ),
    
    "tix": FilterFieldConfiguration(
        displayName: "MTGO TIX Price",
        fieldType: .text,
        aliases: ["tix"]
    ),
    
    // MARK: Special Properties
    "stamp": FilterFieldConfiguration(
        displayName: "Security Stamp",
        fieldType: .enumeration(options: [
            "oval", "triangle", "acorn", "arena", "circle", "heart"
        ]),
        aliases: ["stamp"]
    ),
    
    "promo": FilterFieldConfiguration(
        displayName: "Promo Type",
        fieldType: .text,
        aliases: ["promo"]
    ),
    
    "direction": FilterFieldConfiguration(
        displayName: "Card Direction",
        fieldType: .enumeration(options: [
            "front", "back"
        ]),
        aliases: ["direction", "side"]
    ),
    
    "layout": FilterFieldConfiguration(
        displayName: "Card Layout",
        fieldType: .enumeration(options: [
            "normal", "split", "flip", "transform", "meld", "leveler",
            "class", "saga", "adventure", "mutate", "prototype", "battle",
            "planar", "scheme", "vanguard", "token", "double_faced_token",
            "emblem", "augment", "host", "art_series", "reversible_card"
        ]),
        aliases: ["layout"]
    ),
    
    // MARK: Artwork and Design
    "art": FilterFieldConfiguration(
        displayName: "Art Crop Image",
        fieldType: .text,
        aliases: ["art"]
    ),
    
    "fullart": FilterFieldConfiguration(
        displayName: "Full Art Card",
        fieldType: .text,
        aliases: ["fullart"]
    ),
    
    "finishes": FilterFieldConfiguration(
        displayName: "Card Finishes",
        fieldType: .enumeration(options: [
            "nonfoil", "foil", "etched", "glossy"
        ]),
        aliases: ["finishes", "finish"]
    ),
    
    // MARK: Keywords and Mechanics
    "keyword": FilterFieldConfiguration(
        displayName: "Keyword",
        fieldType: .text,
        aliases: ["keyword", "kw"]
    ),
    
    // MARK: Commander Specific
    "commander": FilterFieldConfiguration(
        displayName: "Commander",
        fieldType: .text,
        aliases: ["commander", "cmd"]
    ),
    
    "colors": FilterFieldConfiguration(
        displayName: "Color Count",
        fieldType: .numeric(range: 0...5, step: 1),
        aliases: ["colors"]
    ),
    
    // MARK: Creature Types and Spell Types
    "creaturetype": FilterFieldConfiguration(
        displayName: "Creature Type",
        fieldType: .text,
        aliases: ["creaturetype", "creature"]
    ),
    
    "spelltype": FilterFieldConfiguration(
        displayName: "Spell Type",
        fieldType: .text,
        aliases: ["spelltype"]
    ),
    
    // MARK: Date and Release
    "date": FilterFieldConfiguration(
        displayName: "Release Date",
        fieldType: .text,
        aliases: ["date"]
    ),
    
    // MARK: Special Searches
    "lore": FilterFieldConfiguration(
        displayName: "Lore Text",
        fieldType: .text,
        aliases: ["lore"]
    ),
    
    "atag": FilterFieldConfiguration(
        displayName: "Art Tags",
        fieldType: .text,
        aliases: ["atag"]
    ),
    
    "prefer": FilterFieldConfiguration(
        displayName: "Prefer Version",
        fieldType: .enumeration(options: [
            "oldest", "newest"
        ]),
        aliases: ["prefer"]
    ),
    
    "unique": FilterFieldConfiguration(
        displayName: "Unique Prints",
        fieldType: .enumeration(options: [
            "cards", "art", "prints"
        ]),
        aliases: ["unique"]
    ),
    
    // MARK: Additional Filters
    "include": FilterFieldConfiguration(
        displayName: "Include Extras",
        fieldType: .enumeration(options: [
            "extras", "variations", "multilingual"
        ]),
        aliases: ["include"]
    ),
    
    "order": FilterFieldConfiguration(
        displayName: "Sort Order",
        fieldType: .enumeration(options: [
            "name", "set", "released", "rarity", "color", "usd", "tix", "eur",
            "cmc", "power", "toughness", "edhrec", "penny", "artist", "review"
        ]),
        aliases: ["order"]
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
