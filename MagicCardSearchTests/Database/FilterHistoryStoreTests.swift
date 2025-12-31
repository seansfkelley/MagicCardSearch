//
//  FilterHistoryTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//

import Testing
import Foundation
@testable import MagicCardSearch

@Suite
class FilterHistoryStoreTests {
    // MARK: - Filter Entry Tests

    @Test("records usage of a single filter")
    func recordFilterUsage() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")

        try db.filterHistory.recordUsage(of: colorFilter)

        let entries = try db.filterHistory.allFiltersChronologically
        try #require(entries.count == 1)
        #expect(entries[0].filter == colorFilter)
    }

    @Test("updates last used date when recording usage of an existing filter")
    func updateExistingFilter() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1060) // 60 seconds later

        try db.filterHistory.recordUsage(of: colorFilter, at: firstDate)
        let entries1 = try db.filterHistory.allFiltersChronologically

        try #require(entries1.count == 1)
        #expect(entries1[0].lastUsedAt == firstDate)

        try db.filterHistory.recordUsage(of: colorFilter, at: secondDate)
        let entries2 = try db.filterHistory.allFiltersChronologically

        try #require(entries2.count == 1)
        #expect(entries2[0].lastUsedAt == secondDate)
    }

    @Test("deletes a filter from history")
    func deleteFilter() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        try db.filterHistory.recordUsage(of: colorFilter)
        try db.filterHistory.recordUsage(of: oracleFilter)

        var entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.count == 2)

        try db.filterHistory.deleteUsage(of: colorFilter)

        entries = try db.filterHistory.allFiltersChronologically
        try #require(entries.count == 1)
        #expect(entries[0].filter == oracleFilter)
    }

    @Test("does nothing when deleting a nonexistent filter")
    func deleteNonexistentFilter() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        try db.filterHistory.recordUsage(of: colorFilter)

        try db.filterHistory.deleteUsage(of: oracleFilter)

        let entries = try db.filterHistory.allFiltersChronologically
        try #require(entries.count == 1)
        #expect(entries[0].filter == colorFilter)
    }

    @Test("sorted filter history returns entries in reverse chronological order")
    func sortedFilterHistory() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1120) // 2 minutes later
        let thirdDate = Date(timeIntervalSinceReferenceDate: 1240) // 4 minutes from start

        try db.filterHistory.recordUsage(of: colorFilter, at: firstDate)
        try db.filterHistory.recordUsage(of: setFilter, at: thirdDate)
        // Out of order!
        try db.filterHistory.recordUsage(of: oracleFilter, at: secondDate)

        let sorted = try db.filterHistory.allFiltersChronologically

        try #require(sorted.count == 3)
        #expect(sorted[0].filter == setFilter)
        #expect(sorted[1].filter == oracleFilter)
        #expect(sorted[2].filter == colorFilter)
    }

    // MARK: - Garbage Collection Tests

    @Test("garbage collection removes filters beyond hard limit")
    func garbageCollectHardLimit() throws {
        let db = try SQLiteDatabase.initialize()

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1090) // 90 seconds later
        let thirdDate = Date(timeIntervalSinceReferenceDate: 1180) // 3 minutes from start

        try db.filterHistory.recordUsage(of: colorFilter, at: firstDate)
        try db.filterHistory.recordUsage(of: setFilter, at: thirdDate)
        // Out of order!
        try db.filterHistory.recordUsage(of: oracleFilter, at: secondDate)

        var entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.count == 3)

        try db.filterHistory.garbageCollect(hardLimit: 2, softLimit: 1, cutoffDate: Date(timeIntervalSinceReferenceDate: 0))

        entries = try db.filterHistory.allFiltersChronologically
        try #require(entries.count == 1)
        #expect(entries[0].filter == setFilter)
    }

    @Test("garbage collection preserves filters below hard limit")
    func garbageCollectBelowHardLimit() throws {
        let db = try SQLiteDatabase.initialize()

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        try db.filterHistory.recordUsage(of: colorFilter)
        try db.filterHistory.recordUsage(of: oracleFilter)

        var entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.count == 2)

        try db.filterHistory.garbageCollect(hardLimit: 10, softLimit: 5, cutoffDate: Date(timeIntervalSinceReferenceDate: 0))

        entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.count == 2)
    }

    @Test("garbage collection removes old filters")
    func garbageCollectOldFilters() throws {
        let db = try SQLiteDatabase.initialize()
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        let date = Date(timeIntervalSinceReferenceDate: 1000)

        try db.filterHistory.recordUsage(of: colorFilter, at: date)
        try db.filterHistory.recordUsage(of: oracleFilter, at: date)

        var entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.count == 2)

        // Garbage collect with cutoff date right now should delete everything.
        try db.filterHistory.garbageCollect(cutoffDate: Date())

        entries = try db.filterHistory.allFiltersChronologically
        #expect(entries.isEmpty)
    }
}
