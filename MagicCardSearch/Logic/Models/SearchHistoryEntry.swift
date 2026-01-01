//
//  FilterHistoryEntry.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import Foundation
import SQLiteData

@Table
struct SearchHistoryEntry: Identifiable {
    let id: Int64?
    let lastUsedAt: Date
    @Column(as: [SearchFilter].StableJSONRepresentation.self)
    let filters: [SearchFilter]

    init(filters: [SearchFilter], at date: Date = .init()) {
        self.id = nil
        self.lastUsedAt = date
        self.filters = filters
    }
}
