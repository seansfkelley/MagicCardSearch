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

private let logger = Logger(label: "ScryfallCatalogBlobs")

private let oneDay: TimeInterval = 60 * 60 * 24
private let jsonDecoder = JSONDecoder()
private let jsonEncoder = JSONEncoder()

private typealias CatalogType = Catalog.`Type`

// swiftlint:disable attributes
@MainActor
@Observable
class ScryfallCatalogBlobs {
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

    public func initialize() async {
        guard !isRunningTests() else {
            logger.info("skipping ScryfallCatalogs initialization in test environment")
            return
        }

        let client = ScryfallClient(networkLogLevel: .minimal)

        await fetch("sets") { try await client.getSets().data }
        await fetch("symbology") { try await client.getSymbology().data }
        // TODO: Symbols.

        for type in CatalogType.allCases {
            await fetch(type.rawValue) {
                try await client.getCatalog(catalogType: type).data
            }
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
}
// swiftlint:enable attributes
