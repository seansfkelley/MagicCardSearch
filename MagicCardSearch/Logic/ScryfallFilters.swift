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

struct ScryfallFilterType {
    let canonicalName: String
    let aliases: Set<String>
    let enumerationValues: Set<String>?
    let supportsNumeric: Bool
    
    init(_ name: String, _ aliases: Set<String> = [], enumerationValues: Set<String>? = nil, supportsNumeric: Bool = false) {
        self.canonicalName = name
        self.aliases = aliases
        self.enumerationValues = enumerationValues
        self.supportsNumeric = supportsNumeric
    }
}

private let scryfallSupportedFormats = Set([
    "standard", "future", "historic", "timeless", "gladiator", "pioneer", "modern", "legacy",
    "pauper", "vintage", "penny", "commander", "oathbreaker", "standardbrawl", "brawl",
    "alchemy", "paupercommander", "duel", "oldschool", "premodern", "predh"
])

private let scryfallIsEnumerationValues = Set([
    // Mana Costs
    "hybrid", "phyrexian",
    // Multi-faced Cards
    "split", "flip", "transform", "meld", "leveler", "dfc", "mdfc",
    // Spells, Permanents, and Effects
    "spell", "permanent", "historic", "party", "modal", "vanilla", "frenchvanilla", "bear",
    // Extra Cards and Funny Cards
    "funny",
    // Sets and Blocks
    // n.b. the documentation claims there are others but doesn't list them
    "booster", "planeswalker_deck", "league", "buyabox", "giftbox", "intro_pack",
    "gameday", "prerelease", "release", "fnm", "judge_gift", "arena_league",
    "player_rewards", "media_insert", "instore", "convention", "set_promo",
    // Format Legality
    "commander", "brawler", "companion", "duelcommander", "reserved"
    // Border, Frame, Foil & Resolution
    "full", "foil", "nonfoil", "etched", "glossy", "hires", "universesbeyond",
    // Games, Promos, & Spotlights
    "digital", "promo", "spotlight", "scryfallpreview",
    // Reprints
    "reprint", "unique",
    // Shortcuts and Nicknames
    "bikeland", "cycleland", "bicycleland", "bounceland", "karoo", "canopyland", "canland",
    "checkland", "dual", "fastland", "fetchland", "filterland", "gainland", "painland",
    "scryland", "surveilland", "shadowland", "shockland", "storageland", "creatureland",
    "triland", "tangoland", "battleland", "masterpiece"
])

// MARK: - Filter Definitions
// translated from https://scryfall.com/docs/syntax and kept in the same order/categories
private let scryfallFilterTypes: [ScryfallFilterType] = [
    // MARK: - Color and Color Identity
    .init("color", ["c"]),
    .init("identity", ["id"]),
    // see also `has`
    
    // MARK: - Card Types
    .init("type", ["t"]),
    
    // MARK: - Card Text
    .init("oracle", ["o"]),
    .init("fulloracle", ["fo"]),
    .init("keyword", ["kw"]),
    
    // MARK: - Mana Costs
    .init("mana", ["m"]),
    .init("manavalue", ["mv"], enumerationValues: ["even", "odd"], supportsNumeric: true),
    .init("devotion"),
    .init("produces"),
    // see also `is`
    
    // MARK: - Power, Toughness, and Loyalty
    .init("power", ["pow"], enumerationValues: ["toughness", "tou", "powtou", "pt", "loyalty", "loy"], supportsNumeric: true),
    .init("toughness", ["tou"], enumerationValues: ["power", "pow", "powtou", "pt", "loyalty", "loy"], supportsNumeric: true),
    .init("powtou", ["pt"], enumerationValues: ["power", "pow", "toughness", "tou", "loyalty", "loy"], supportsNumeric: true),
    .init("loyalty", ["loy"], enumerationValues: ["power", "pow", "toughness", "tou", "powtou", "pt"], supportsNumeric: true),
    
    // MARK: - Multi-faced Cards
    // empty
    // see also `is`
    
    // MARK: - Spells, Permanents, and Effects
    // empty
    // see also `is`
    
    // MARK: - Extra Cards and Funny Cards
    .init("include", enumerationValues: ["extras"]),
    // see also `is`
    
    // MARK: - Rarity
    .init("rarity", ["r"], enumerationValues: ["common", "uncommon", "rare", "mythic", "special", "bonus"])
    // see also `new` and `in`
    
    // MARK: - Sets and Blocks
    .init("set", ["s", "edition", "e"]), // n.b. technically this would be an enumeration but there are tooooooo many and they change too often
    .init("number", ["cn"], supportsNumeric: true),
    .init("block", ["b"]), // n.b. technically this would be an enumeration but there are tooooooo many also
    .init("st", enumerationValues: [
        // primary product types
        "core", "expansion", "draftinnovation",
        // series of products
        "masters", "funny", "commander", "duel_deck", "from_the_vault", "spellbook", "premium_deck",
        // specialized types
        "alchemy", "archenemy", "masterpiece", "memorabilia", "planechase", "promo", "starter", "token", "treasure_chest", "vanguard",
    ])
    // see also `is` and `in`
    
    // MARK: - Cubes
    .init("cube", enumerationValues: [
        "arena", "grixis", "legacy", "chuck", "twisted", "april", "protour", "uncommon",
        "modern", "amaz", "tinkerer", "livethedream", "chromatic", "vintage", "apcube"
    ]),
    
    // MARK: - Format Legality
    .init("format", enumerationValues: scryfallSupportedFormats),
    .init("banned", enumerationValues: scryfallSupportedFormats),
    .init("restricted", enumerationValues: scryfallSupportedFormats),
    // see also `is`
    
    // MARK: - USD/EUR/TIX prices
    .init("usd", supportsNumeric: true),
    .init("eur", supportsNumeric: true),
    .init("tix", supportsNumeric: true),
    .init("cheapest", enumerationValues: ["usd", "eur", "tix"]),
    
    // MARK: - Artist, Flavor Text and Watermark
    .init("artist", ["a"], supportsNumeric: true),
    .init("flavor", ["ft"]),
    .init("watermark", ["wm"]),
    .init("illustrations", supportsNumeric: true)
    // see also `has` and `new`
    
    // MARK: - Border, Frame, Foil & Resolution
    .init("border", enumerationValues: ["black", "white", "silver", "borderless"]),
    .init("frame", enumerationValues: ["1993", "1997", "2003", "2015", "future", "legendary", "colorshifted", "tombstone", "enchantment"]),
    .init("stamp", enumerationValues: ["oval", "acorn", "triangle", "arena"]),
    // see also `is` and `new`
    
    // MARK: - Games, Promos, & Spotlights
    .init("game", enumerationValues: ["paper", "arena", "mtgo"]),
    // see also `in`
    
    // MARK: - Year
    .init("year", enumerationValues: ["now", "today"]), // n.b. would also include sets, but, you know
    
    // MARK: - Tagger Tags
    .init("art", ["atag", "arttag"]),
    .init("function", ["otag", "oracletag"]),
    
    // MARK: - Reprints
    .init("prints", supportsNumeric: true),
    .init("sets", supportsNumeric: true),
    .init("paperprints", supportsNumeric: true),
    .init("papersets", supportsNumeric: true),
    // see also `is`
    
    // MARK: - Languages
    .init("language", ["lang"], enumerationValues: ["any"]), // also language codes and language names
    // see also `new` and `in`
    
    // MARK: - Shortcuts and Nicknames
    // empty
    // see also `is`
    
    // MARK: - Regular Expressions
    // empty
    
    // MARK: - Exact Names
    // empty
    
    // MARK: - Using "OR"
    // empty
    
    // MARK: - Nesting Conditions
    // empty
    
    // MARK: - Display Keywords
    .init("unique", enumerationValues: ["cards", "prints", "art"]),
    // `display` not supported
    .init("order", enumerationValues: [
        "artist", "cmc", "power", "toughness", "set", "name", "usd", "tix", "eur",
        "rarity", "color", "released", "spoiled", "edhrec", "penny", "review",
    ]),
    .init("prefer", enumerationValues: [
        "oldest", "newest", "usd-low", "usd-high", "eur-low", "eur-high", "tix-low", "tix-high", "promo"
    ]),
    .init("direction", enumerationValues: ["asc", "desc"]),
    
    // MARK: - Combined from Multiple Preceding Categories
    .init("has", enumerationValues: [
        // Color and Color Identity
        "indicator",
        // Artist, Flavor Text and Watermark
        "watermark",
    ]),
    .init("is", enumerationValues: scryfallIsEnumerationValues),
    .init("not", enumerationValues: scryfallIsEnumerationValues),
    .init("new", enumerationValues: [
        // Rarity
        "rarity",
        // Artist, Flavor Text and Watermark
        "art", "artist", "flavor",
        // Border, Frame, Foil & Resolution
        "frame",
        // Languages
        "language",
    ]),
    .init("in", enumerationValues: [
        // Rarity
        "common", "uncommon", "rare", "mythic", "special", "bonus",
        // Sets and Blocks
        // empty -- this would require enumerating all the sets, blocks, and product types
        // Games, Promos, & Spotlights
        "paper", "arena", "mtgo",
        // Languages
        // empty -- we don't enumerate the languages
    ])
]

let filterFieldConfigurations: [String: FilterFieldConfiguration] = [
    "color": FilterFieldConfiguration("color", ["c"]),
    "identity": FilterFieldConfiguration("identity", ["id"]),
    "has": FilterFieldConfiguration("has"),
    "type": FilterFieldConfiguration("type", "t"),
    
    
    
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
            "full", "hires", "rebalanced", "promo"
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
            "full", "hires", "rebalanced", "promo"
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
