//
//  FilterFieldConfiguration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

// MARK: - Scryfall Filter Type

struct IndexedEnumerationValues {
    let sortedByLength: [String]
    let sortedAlphabetically: [String]
    
    init(_ values: [String]) {
        self.sortedByLength = values.sorted(using: [
            KeyPathComparator(\.count),
            KeyPathComparator(\.self, comparator: .localizedStandard),
        ])
        self.sortedAlphabetically = values.sorted(using: [
            KeyPathComparator(\.self, comparator: .localizedStandard),
        ])
    }
}

struct ScryfallFilterType: Sendable {
    enum ComparisonKinds: Sendable {
        case all, equality
    }
    
    let canonicalName: String
    let allNames: Set<String>
    let enumerationValues: IndexedEnumerationValues?
    let comparisonKinds: ComparisonKinds
    
    init(
        _ name: String,
        _ aliases: Set<String> = [],
        enumerationValues: [String]? = nil,
        comparisonKinds: ComparisonKinds = .equality
    ) {
        self.canonicalName = name
        self.allNames = Set([canonicalName]).union(aliases)
        self.enumerationValues = enumerationValues.map { IndexedEnumerationValues($0) }
        self.comparisonKinds = comparisonKinds
    }
}

private let scryfallColorAliases = [
    // guild
    "azorius", "dimir", "rakdos", "golgari", "boros", "simic", "selesnya", "orzhov", "izzet", "gruul",
    // shard
    "bant", "esper", "grixis", "jund", "naya",
    // wedge
    "abzan", "jeskai", "sultai", "mardu", "temur",
    // college
    "lorehold", "prismari", "quandrix", "witherbloom", "silverquill",
    // family
    "brokers", "obscura", "maestros", "riveteers", "cabaretti",
    // four-color
    "chaos", "aggression", "altruism", "growth", "artifice",
]

private let scryfallSupportedFormats = [
    "standard", "future", "historic", "timeless", "gladiator", "pioneer", "modern", "legacy",
    "pauper", "vintage", "penny", "commander", "oathbreaker", "standardbrawl", "brawl",
    "alchemy", "paupercommander", "duel", "oldschool", "premodern", "predh",
]

private let scryfallIsEnumerationValues = [
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
    "triland", "tangoland", "battleland", "masterpiece",
    // Not listed in the documentation, but discovered/mentioned elsewhere
    "gamechanger", "reversible", "fullart",
]

// MARK: - Filter Definitions
// translated from https://scryfall.com/docs/syntax and kept in the same order/categories
let scryfallFilterTypes: [ScryfallFilterType] = [
    // MARK: - Name
    .init("name"),
    
    // MARK: - Color and Color Identity
    .init("color", ["c"], enumerationValues: scryfallColorAliases, comparisonKinds: .all),
    .init("identity", ["id"], enumerationValues: scryfallColorAliases, comparisonKinds: .all),
    // see also `has`
    
    // MARK: - Card Types
    .init("type", ["t"]), // Enumeration values loaded from Scryfall.
    
    // MARK: - Card Text
    .init("oracle", ["o"]),
    .init("fulloracle", ["fo"]),
    .init("keyword", ["kw"]), // Enumeration values loaded from Scryfall.
    
    // MARK: - Mana Costs
    .init("mana", ["m"], comparisonKinds: .all),
    .init("manavalue", ["mv"], enumerationValues: ["even", "odd"], comparisonKinds: .all),
    .init("devotion", comparisonKinds: .all),
    .init("produces", comparisonKinds: .all),
    // see also `is`
    
    // MARK: - Power, Toughness, and Loyalty
    .init("power", ["pow"], enumerationValues: ["toughness", "tou", "powtou", "pt", "loyalty", "loy"], comparisonKinds: .all),
    .init("toughness", ["tou"], enumerationValues: ["power", "pow", "powtou", "pt", "loyalty", "loy"], comparisonKinds: .all),
    .init("powtou", ["pt"], enumerationValues: ["power", "pow", "toughness", "tou", "loyalty", "loy"], comparisonKinds: .all),
    .init("loyalty", ["loy"], enumerationValues: ["power", "pow", "toughness", "tou", "powtou", "pt"], comparisonKinds: .all),
    
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
    .init(
        "rarity",
        ["r"],
        enumerationValues: ["common", "uncommon", "rare", "mythic", "special", "bonus"],
        comparisonKinds: .all,
    ),
    // see also `new` and `in`
    
    // MARK: - Sets and Blocks
    .init("set", ["s", "edition", "e"]), // Enumeration values loaded from Scryfall.
    .init("number", ["cn"], comparisonKinds: .all),
    .init("block", ["b"]), // Enumeration values loaded from Scryfall.
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
        "modern", "amaz", "tinkerer", "livethedream", "chromatic", "vintage", "apcube",
    ]),
    
    // MARK: - Format Legality
    .init("format", ["f"], enumerationValues: scryfallSupportedFormats),
    .init("banned", enumerationValues: scryfallSupportedFormats),
    .init("restricted", enumerationValues: scryfallSupportedFormats),
    // see also `is`
    
    // MARK: - USD/EUR/TIX prices
    .init("usd", comparisonKinds: .all),
    .init("eur", comparisonKinds: .all),
    .init("tix", comparisonKinds: .all),
    .init("cheapest", enumerationValues: ["usd", "eur", "tix"]),
    
    // MARK: - Artist, Flavor Text and Watermark
    .init("artist", ["a"], comparisonKinds: .all),
    .init("flavor", ["ft"]),
    .init("watermark", ["wm"]), // Enumeration values loaded from Scryfall.
    .init("illustrations", comparisonKinds: .all),
    // see also `has` and `new`
    
    // MARK: - Border, Frame, Foil & Resolution
    .init("border", enumerationValues: ["black", "white", "silver", "borderless"]),
    .init("frame", enumerationValues: [
        "1993", "1997", "2003", "2015", "future",
        // https://scryfall.com/docs/api/frames
        "colorshifted", "companion", "compasslanddf", "convertdfc", "devoid", "draft", "enchantment",
        "etched", "extendedart", "fandfc", "inverted", "legendary", "lesson", "miracle",
        "mooneldrazidfc", "originpwdfc", "shatteredglass", "showcase", "snow", "spree", "sunmoondfc",
        "tombstone", "upsidedowndfc", "waxingandwaningmoondfc",
        // discovered independently, not listed in the documentation
        "old", "new",
    ]),
    .init("stamp", enumerationValues: ["oval", "acorn", "triangle", "arena"]),
    // see also `is` and `new`
    
    // MARK: - Games, Promos, & Spotlights
    .init("game", enumerationValues: ["paper", "arena", "mtgo"]),
    // see also `in`
    
    // MARK: - Year
    .init(
        "year",
        // n.b. would also include sets, but, you know
        enumerationValues: ["now", "today"],
        comparisonKinds: .all
    ),
    .init(
        "date",
        // n.b. would also include sets, but, you know
        enumerationValues: ["now", "today"],
        comparisonKinds: .all
    ),
    
    // MARK: - Tagger Tags
    .init("art", ["atag", "arttag"]),
    .init("function", ["otag", "oracletag"]),
    
    // MARK: - Reprints
    .init("prints", comparisonKinds: .all),
    .init("sets", comparisonKinds: .all),
    .init("paperprints", comparisonKinds: .all),
    .init("papersets", comparisonKinds: .all),
    // see also `is`
    
    // MARK: - Languages
    .init("language", ["l", "lang"], enumerationValues: ["any"]), // also language codes and language names
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
    .init("direction", ["dir"], enumerationValues: ["asc", "desc"]),
    
    // MARK: - Combined from Multiple Preceding Categories
    .init("has", enumerationValues: [
        // Color and Color Identity
        "indicator",
        // Artist, Flavor Text and Watermark
        "watermark",
        // Not listed in the documentation, but discovered/mentioned elsewhere
        "phyrexian", "hybrid",
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
    ]),
    
    // MARK: - Layout
    // https://scryfall.com/docs/api/layouts
    .init("layout", enumerationValues: [
        "normal", "split", "flip", "transform", "meld", "leveler", "saga", "adventure", "planar",
        "scheme", "vanguard", "token", "emblem", "augment", "host", "class", "battle", "case",
        "mutate", "prototype", "unknown", "modaldfc", "doublesided", "doublefacedtoken",
        "artseries", "reversiblecard",
    ]),
]

// MARK: - Derived Constants

let scryfallFilterByType: [String: ScryfallFilterType] = {
    var lookup: [String: ScryfallFilterType] = [:]
    for filterType in scryfallFilterTypes {
        for name in filterType.allNames {
            assert(lookup[name] == nil)
            lookup[name] = filterType
        }
    }
    return lookup
}()
