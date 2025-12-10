//
//  Card.Ruling+Extensions.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//
import Foundation
import ScryfallKit

extension Card.Ruling {
    var publishedAtAsDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: publishedAt)
    }
}
