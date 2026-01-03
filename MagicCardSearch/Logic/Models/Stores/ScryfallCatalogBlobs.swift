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

/// A property wrapper that manages fetching, parsing, transforming, and caching blob data.
///
/// This wrapper encapsulates the pattern of:
/// - Observing a database blob entry via `@FetchOne`
/// - Lazily parsing JSON on first access
/// - Transforming the parsed data
/// - Caching the result
/// - Invalidating the cache when the underlying blob changes
@propertyWrapper
struct CachedParsedBlob<Payload: Codable, Transformed> {
    private var blobEntry: BlobEntry?
    private var cache: Result<Transformed, Error>?
    private let transform: (Payload) -> Transformed

    var wrappedValue: Transformed? {
        mutating get {
            if case .success(let transformed) = cache {
                return transformed
            }
            
            guard let blobEntry else { return nil }
            
            do {
                let parsed = try jsonDecoder.decode(Payload.self, from: blobEntry.value)
                let result = transform(parsed)
                cache = .success(result)
                return result
            } catch {
                logger.error("error decoding blob", metadata: [
                    "key": "\(blobEntry.key)",
                    "error": "\(error)",
                ])
                cache = .failure(error)
                return nil
            }
        }
    }

    init(_ transform: @escaping (Payload) -> Transformed) {
        self.transform = transform
    }
}

@MainActor
@Observable
class ScryfallCatalogBlobs {
    @CachedParsedBlob({ (array: [MTGSet]) in
        Dictionary(uniqueKeysWithValues: array.map { (SetCode($0.code), $0) })
    })
    @ObservationIgnored
    @FetchOne(BlobEntry.where { $0.key == "sets" })
    public var sets

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

        typealias CatalogType = Catalog.`Type`
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
