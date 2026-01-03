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

protocol HasData<Data> {
    associatedtype Data: Codable
    var data: Data { get }
}
extension ObjectList: HasData {}
extension Catalog: HasData {}

@MainActor
struct ScryfallCatalogBlobs {
    @Dependency(\.defaultDatabase) private var database

    // TODO: Does this need to be observable for this to work?
    @FetchOne(BlobEntry.where { $0.key == "sets" }) private var sets_
    // TODO: Can this be a read-once cache situation?
    public var sets: [MTGSet]? { `get`(sets_) }

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

    private init() {}

    public static func initialize() async {
        let catalog = ScryfallCatalogBlobs()
        let client = ScryfallClient(networkLogLevel: .minimal)

        await catalog.fetch("sets", using: client.getSets)
        await catalog.fetch("symbology", using: client.getSymbology)
        // TODO: Symbols.

        typealias CatalogType = Catalog.`Type`
        for type in CatalogType.allCases {
            await catalog.fetch(type.rawValue) {
                try await client.getCatalog(catalogType: type)
            }
        }
    }

    fileprivate func fetch<T: HasData>(_ key: String, using fetcher: () async throws -> T) async {
        let existing: BlobEntry?
        do {
            existing = try await database.read { db in
                try BlobEntry.all.where { $0.key == key }.fetchOne(db)
            }
        } catch {
            logger.warning("failed while reading blob from database; will re-fetch", metadata: [
                "key": "\(key)",
                "error": "\(error)",
            ])
        }

        if let existing, existing.insertedAt >= Date(timeIntervalSinceNow: -30 * oneDay) {
            do {
                _ = try jsonDecoder.decode(Catalog.self, from: existing.value)
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

    fileprivate func loadSets() async throws {
        let existing = try await database.read { db in
            try BlobEntry.all.where { $0.key == "sets" }.fetchOne(db)
        }

        if let existing, existing.insertedAt >= Date(timeIntervalSinceNow: -30 * oneDay) {
            do {
                _ = try jsonDecoder.decode(Catalog.self, from: existing.value)
                logger.info("not fetching; already have valid blob")
            } catch {
                logger.warning("blob existed but could not be parsed; will re-fetch", metadata: [
                    "error": "\(error)",
                ])
            }
        }

        logger.info("fetching sets...")
        let sets =
        if sets.hasMore ?? false {
            logger.warning("Scryfall unexpectedly reported that there are multiple pages of sets; will not fetch them")
        }
        let payload = Catalog.sets(sets.data)
        _ = try await database.write { db in
            try BlobEntry(key: payload.key, value: jsonEncoder.encode(payload))
        }
    }
}
