//
//  ScryfallCatalogBlobs.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-02.
//
import Foundation
import ScryfallKit
import Logging
import SQLiteData

private let logger = Logger(label: "ScryfallCatalogs")

private let oneDay: TimeInterval = 60 * 60 * 24
private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

private typealias CatalogType = Catalog.`Type`

// swiftlint:disable attributes
@MainActor
@Observable
class ScryfallCatalogs {
    @ObservationIgnored
    @TransformedBlob("sets", { data in
        let parsed = try jsonDecoder.decode([MTGSet].self, from: data)
        return Dictionary(uniqueKeysWithValues: parsed.map { (SetCode($0.code), $0) })
    })
    public var sets: [SetCode: MTGSet]?

    @ObservationIgnored
    @TransformedBlob("symbology", { data in
        let parsed = try jsonDecoder.decode([Card.Symbol].self, from: data)
        return Dictionary(uniqueKeysWithValues: parsed.map { (SymbolCode($0.symbol), $0) })
    })
    public var symbology: [SymbolCode: Card.Symbol]?

    @ObservationIgnored
    @TransformedBlob("symbolSvgs")
    public var symbolSvgs: [SymbolCode: Data]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.abilityWords.rawValue)
    public var abilityWords: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.artifactTypes.rawValue)
    public var artifactTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.artistNames.rawValue)
    public var artistNames: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.battleTypes.rawValue)
    public var battleTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.cardNames.rawValue)
    public var cardNames: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.cardTypes.rawValue)
    public var cardTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.creatureTypes.rawValue)
    public var creatureTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.enchantmentTypes.rawValue)
    public var enchantmentTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.flavorWords.rawValue)
    public var flavorWords: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.keywordAbilities.rawValue)
    public var keywordAbilities: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.keywordActions.rawValue)
    public var keywordActions: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.landTypes.rawValue)
    public var landTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.loyalties.rawValue)
    public var loyalties: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.planeswalkerTypes.rawValue)
    public var planeswalkerTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.powers.rawValue)
    public var powers: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.spellTypes.rawValue)
    public var spellTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.supertypes.rawValue)
    public var supertypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.toughnesses.rawValue)
    public var toughnesses: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.watermarks.rawValue)
    public var watermarks: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.wordBank.rawValue)
    public var wordBank: [String]?

    private let database: any DatabaseWriter

    init(database: DatabaseWriter) {
        self.database = database
    }

    public func hydrate() async {
        guard !isRunningTests() else {
            logger.info("skipping ScryfallCatalogs initialization in test environment")
            return
        }

        let client = ScryfallClient(networkLogLevel: .minimal)

        for type in CatalogType.allCases {
            await fetch(type.rawValue) {
                try await client.getCatalog(catalogType: type).data
            }
        }

        await fetch("sets") { try await client.getSets().data }
        await fetch("symbology") { try await client.getSymbology().data }

        let symbology: [Card.Symbol]?
        do {
            symbology = try await database.read { db in
                if let blob = try (BlobEntry.where { $0.key == "symbology" }.fetchOne(db)) {
                    try jsonDecoder.decode([Card.Symbol].self, from: blob.value)
                } else {
                    nil
                }
            }
        } catch {
            symbology = nil
            logger.warning("failed to load or parse symbology; will not attempt to load SVGs", metadata: [
                "error": "\(error)",
            ])
        }

        if let symbology {
            await fetch("symbolSvgs") { await fetchSymbolSvgs(symbols: symbology) }
        }
    }

    // swiftlint:disable:next function_body_length
    private func fetch<T: Codable>(_ key: String, expiringAfterDays expirationInDays: Int = 30, using fetcher: () async throws -> T) async {
        let existing: BlobEntry?
        do {
            existing = try await database.read { db in
                try BlobEntry.all.where { $0.key == key }.fetchOne(db)
            }
        } catch {
            existing = nil
            logger.warning("failed while reading blob from database; will re-fetch", metadata: [
                "key": "\(key)",
                "error": "\(error)",
            ])
        }

        if let existing {
            if existing.insertedAt >= Date(timeIntervalSinceNow: -Double(expirationInDays) * oneDay) {
                do {
                    _ = try jsonDecoder.decode(T.self, from: existing.value)
                    logger.info("not fetching; already have valid blob", metadata: [
                        "key": "\(key)",
                    ])
                    return
                } catch {
                    logger.warning("blob existed but could not be parsed; will re-fetch", metadata: [
                        "key": "\(key)",
                        "error": "\(error)",
                    ])
                }
            } else {
                logger.info("blob existed but is expired; will re-fetch", metadata: [
                    "key": "\(key)",
                ])
            }
        }

        let result: T
        do {
            result = try await fetcher()
        } catch {
            logger.error("error fetching blob data from Scryfall; will continue without", metadata: [
                "key": "\(key)",
                "error": "\(error)",
            ])
            return
        }

        do {
            let value = try jsonEncoder.encode(result)

            _ = try await database.write { db in
                try BlobEntry
                    .insert { BlobEntry(key: key, value: value) }
                    .execute(db)
            }
        } catch {
            logger.error("error writing blob to store", metadata: [
                "key": "\(key)",
                "error": "\(error)",
            ])
            return
        }

        logger.info("fetched and cached blob", metadata: [
            "key": "\(key)",
        ])
    }

    private func fetchSymbolSvgs(symbols: [Card.Symbol]) async -> [SymbolCode: Data] {
        logger.info("fetching symbol SVGs...", metadata: [
            "count": "\(symbols.count)",
        ])

        var result: [SymbolCode: Data] = [:]
        let batchSize = 10
        let symbolArray = Array(symbols)

        // n.b. the documentation at https://scryfall.com/docs/api says that the servers at
        // *.scryfall.io do NOT have rate limits, so we'll just limit ourselves to avoid having
        // an unreasonable amount of network traffic/async tasks that we have to manage.
        for batchStart in stride(from: 0, to: symbolArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, symbolArray.count)
            let batch = symbolArray[batchStart..<batchEnd]

            await withTaskGroup(of: (SymbolCode, Data)?.self) { group in
                for symbol in batch {
                    group.addTask {
                        do {
                            if let svgUri = symbol.svgUri,
                                let url = URL(string: svgUri) {
                                logger.debug("fetching symbol SVG", metadata: [
                                    "symbol": "\(symbol.symbol)",
                                    "svgUri": "\(svgUri)",
                                ])
                                let (data, response) = try await URLSession.shared.data(from: url)

                                guard let httpResponse = response as? HTTPURLResponse,
                                      (200...299).contains(httpResponse.statusCode),
                                      !data.isEmpty else {
                                    logger.error("invalid SVG response", metadata: [
                                        "symbol": "\(symbol.symbol)",
                                        "svgUri": "\(svgUri)",
                                        "dataSize": "\(data.count)",
                                    ])
                                    return nil
                                }

                                if String(data: data, encoding: .utf8) == nil {
                                    logger.error("SVG data is not valid UTF-8", metadata: [
                                        "symbol": "\(symbol.symbol)",
                                        "svgUri": "\(svgUri)",
                                        "dataSize": "\(data.count)",
                                    ])
                                    return nil
                                }

                                return (SymbolCode(symbol.symbol), data)
                            } else {
                                return nil
                            }
                        } catch {
                            // FIXME: This will be broken until ALL the SVGs expire.
                            logger.warning(
                                "failed to fetch symbol SVG; this symbol will not render properly",
                                metadata: [
                                    "symbolCode": "\(symbol.symbol)",
                                    "error": "\(error)",
                                ]
                            )
                            return nil
                        }
                    }
                }

                for await fetchedResult in group {
                    if let (symbolCode, data) = fetchedResult {
                        result[symbolCode] = data
                    }
                }
            }
        }

        return result
    }

    // There's got to be a better way to do this...
    subscript(catalogType: Catalog.`Type`) -> [String]? {
        switch catalogType {
        case .abilityWords: abilityWords
        case .artifactTypes: artifactTypes
        case .artistNames: artistNames
        case .battleTypes: battleTypes
        case .cardNames: cardNames
        case .cardTypes: cardTypes
        case .creatureTypes: creatureTypes
        case .enchantmentTypes: enchantmentTypes
        case .flavorWords: flavorWords
        case .keywordAbilities: keywordAbilities
        case .keywordActions: keywordActions
        case .landTypes: landTypes
        case .loyalties: loyalties
        case .planeswalkerTypes: planeswalkerTypes
        case .powers: powers
        case .spellTypes: spellTypes
        case .supertypes: supertypes
        case .toughnesses: toughnesses
        case .watermarks: watermarks
        case .wordBank: wordBank
        }
    }
}
// swiftlint:enable attributes
