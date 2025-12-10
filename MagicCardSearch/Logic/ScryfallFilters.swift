//
//  FilterFieldConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

// MARK: - Scryfall Filter Type

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
    
    // TODO: Cache this.
    var names: Set<String> {
        return Set([canonicalName]).union(aliases)
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
    "commander", "brawler", "companion", "duelcommander", "reserved",
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
let scryfallFilterTypes: [ScryfallFilterType] = [
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
    .init("rarity", ["r"], enumerationValues: ["common", "uncommon", "rare", "mythic", "special", "bonus"]),
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
    ]),
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
    .init("illustrations", supportsNumeric: true),
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

// MARK: - Derived Constants

let scryfallFilterByType: [String: ScryfallFilterType] = {
    var lookup: [String: ScryfallFilterType] = [:]
    for filterType in scryfallFilterTypes {
        lookup[filterType.canonicalName] = filterType
        for alias in filterType.aliases {
            assert(lookup[alias] == nil)
            lookup[alias] = filterType
        }
    }
    return lookup
}()
