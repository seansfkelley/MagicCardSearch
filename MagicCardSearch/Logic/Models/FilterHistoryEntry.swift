//
//  FilterHistoryEntry.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import Foundation
import SQLiteData

@Table
struct FilterHistoryEntry {
    let id: Int64
    let lastUsedAt: Date
    @Column(as: SearchFilterRepresentation.self)
    let filter: SearchFilter
}

public struct SearchFilterRepresentation: Codable, QueryRepresentable, QueryBindable, QueryDecodable {
    public var queryOutput: SearchFilter

    public init(queryOutput: SearchFilter) {
        self.queryOutput = queryOutput
    }

    public var queryBinding: QueryBinding {
        do {
            return try .text(String(decoding: jsonEncoder.encode(queryOutput), as: UTF8.self))
        } catch {
            return .invalid(error)
        }
    }

    public init(decoder: inout some QueryDecoder) throws {
        self.init(
            queryOutput: try jsonDecoder.decode(
                QueryOutput.self,
                from: Data(String(decoder: &decoder).utf8)
            )
        )
    }
}

private let jsonDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    return decoder
}()

private let jsonEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    // Unique'ing on the filter itself is pretty dumb, but whatever -- we have to sort the keys to
    // ensure representational consistency.
    encoder.outputFormatting = [.sortedKeys]
    return encoder
}()
