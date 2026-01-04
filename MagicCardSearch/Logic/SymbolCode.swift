//
//  SetCode.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-03.
//
struct SymbolCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String

    init(_ symbol: String) {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let braced =
            trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
            ? trimmed
            : "{\(trimmed)}"
        self.normalized = braced
    }

    var description: String {
        "Symbol\(normalized)"
    }

    var isOversized: Bool {
        // TODO: Consult the symbology, but at the time of writing, this is 100% correct.
        normalized.contains("/")
    }
}
