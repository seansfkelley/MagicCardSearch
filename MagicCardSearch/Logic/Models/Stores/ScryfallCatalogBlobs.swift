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

protocol HasData<Data> {
    associatedtype Data: Codable
    var data: Data { get }
}
extension ObjectList: HasData {}
extension Catalog: HasData {}

@MainActor
@Observable
class ScryfallCatalogBlobs {
    @ObservationIgnored
    // TODO: Does this need to be observable for this to work?
    @FetchOne(BlobEntry.where { $0.key == "sets" }) private var setsObject
    // TODO: Can this be a read-once cache situation?
    public var sets: [SetCode: MTGSet]? {
        guard let array: [MTGSet] = get(setsObject) else { return nil }
        return Dictionary(uniqueKeysWithValues: array.map { (SetCode($0.code), $0) })
    }

    private let database: any DatabaseWriter

    init(database: DatabaseWriter) {
        self.database = database
    }

    private func get<T: Codable>(_ entry: BlobEntry?) -> T? {
        guard let entry else { return nil }

        do {
            return try jsonDecoder.decode(T.self, from: entry.value)
        } catch {
            logger.error("error decoding blob", metadata: [
                "key": "\(entry.key)",
                "error": "\(error)",
            ])
            return nil
        }
    }

    public func initialize() async {
        guard !isRunningTests() else {
            logger.info("skipping ScryfallCatalogs initialization in test environment")
            return
        }

        let client = ScryfallClient(networkLogLevel: .minimal)

        await fetch("sets", using: client.getSets)
        await fetch("symbology", using: client.getSymbology)
        // TODO: Symbols.

        typealias CatalogType = Catalog.`Type`
        for type in CatalogType.allCases {
            await fetch(type.rawValue) {
                try await client.getCatalog(catalogType: type)
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func fetch<T: HasData>(_ key: String, using fetcher: () async throws -> T) async {
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

        if let existing, existing.insertedAt >= Date(timeIntervalSinceNow: -30 * oneDay) {
            do {
                _ = try jsonDecoder.decode(T.Data.self, from: existing.value)
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
            let value = try jsonEncoder.encode(result.data)

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
