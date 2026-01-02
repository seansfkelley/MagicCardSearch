//
//  PinnedFilterEntry.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import Foundation
import SQLiteData

@Table
struct PinnedFilterEntry: Identifiable {
    let id: Int64?
    let pinnedAt: Date
    @Column(as: SearchFilter.StableJSONRepresentation.self)
    let filter: SearchFilter

    init(filter: SearchFilter, at date: Date = .init()) {
        self.id = nil
        self.pinnedAt = date
        self.filter = filter
    }
}
