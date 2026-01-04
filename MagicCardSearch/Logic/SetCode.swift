//
//  SetCode.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-03.
//
struct SetCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String

    init(_ set: String) {
        self.normalized = set.trimmingCharacters(in: .whitespaces).uppercased()
    }

    var description: String {
        "Set[\(normalized)]"
    }
}
