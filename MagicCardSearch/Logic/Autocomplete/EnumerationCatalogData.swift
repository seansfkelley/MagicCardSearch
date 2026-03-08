import Foundation
import FuzzyMatch
import ScryfallKit

struct EnumerationCatalogData: Sendable {
    // These are really noisy in the search results and I can't imagine anyone ever wants them.
    //
    // Maybe in the future we could suggest these if you have narrowed the results far enough that
    // you might actually want to see the 800 memorabilia variants for Avatar, but not when you've
    // only typed "a".
    private static let ignoredSetTypes: Set<MTGSet.Kind> = [
        .token,
        .promo,
        .memorabilia,
    ]

    // n.b. these are named after the corresponding Scryfall filter's canonical name.
    let art: [String]?
    let function: [String]?

    var artist: [String]? {
        catalogs[.artistNames]
    }
    var block: [String]? {
        sets.map { $0.compactMap { $0.block?.replacing(/[^a-zA-Z0-9 ]/, with: "") }.uniqued() }
    }
    var set: [String]? {
        sets.map { $0.flatMap { [$0.code.uppercased(), $0.name] }.map { $0.replacing(/[^a-zA-Z0-9 ]/, with: "") } }
    }
    var keyword: [String]? {
        combined(.keywordAbilities, .abilityWords).map { $0.map { $0.lowercased() } }
    }
    var type: [String]? {
        combined(.supertypes, .cardTypes, .artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes)
    }
    var watermark: [String]? {
        catalogs[.watermarks]
    }

    subscript(_ filter: ScryfallFilterType) -> [String]? {
        switch filter.canonicalName {
        case "type": type
        case "set": set
        case "block": block
        case "keyword": keyword
        case "watermark": watermark
        case "artist": artist
        case "art": art
        case "function": function
        default: nil
        }
    }

    private let catalogs: [Catalog.`Type`: [String]]
    private let sets: [MTGSet]?

    init(
        catalogs: [Catalog.`Type`: [String]],
        sets: [SetCode: MTGSet]?,
        artTags: [String]?,
        oracleTags: [String]?,
    ) {
        self.catalogs = catalogs
        self.sets = sets?.values.filter { !Self.ignoredSetTypes.contains($0.setType) }
        self.art = artTags
        self.function = oracleTags
    }

    @MainActor
    init(scryfallCatalogs: ScryfallCatalogs) {
        typealias CatalogType = Catalog.`Type`

        var catalogs = [CatalogType: [String]]()
        for type in CatalogType.allCases {
            if let data = scryfallCatalogs[type] {
                catalogs[type] = data
            }
        }
        self.init(
            catalogs: catalogs,
            sets: scryfallCatalogs.sets,
            artTags: scryfallCatalogs.artTags,
            oracleTags: scryfallCatalogs.oracleTags,
        )
    }

    private func combined(_ catalogTypes: Catalog.`Type`...) -> [String]? {
        var result: [String] = []
        for type in catalogTypes {
            guard let data = catalogs[type] else {
                return nil
            }
            result.append(contentsOf: data)
        }
        return result
    }
}
