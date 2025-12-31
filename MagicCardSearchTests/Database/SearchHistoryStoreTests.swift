//
//  SearchHistoryStoreTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Testing
import Foundation
@testable import MagicCardSearch

@Suite
class SearchHistoryStoreTests {
    // MARK: - Complete Search Entry Tests

    @Test("records usage of a complete search")
    func recordCompleteSearch() throws {
        let db = try SQLiteDatabase.initialize()
        let filters = [
            SearchFilter.basic(false, "color", .equal, "red"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]

        try db.searchHistory.recordSearch(with: filters)

        let entries = try db.searchHistory.allSearchesChronologically
        try #require(entries.count == 1)
        #expect(entries[0].search == filters)
    }

    @Test("updates last used date when recording usage of an existing search")
    func updateExistingSearch() throws {
        let db = try SQLiteDatabase.initialize()
        let filters = [
            SearchFilter.basic(false, "color", .equal, "red"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1060) // 60 seconds later

        try db.searchHistory.recordSearch(with: filters, at: firstDate)
        let entries1 = try db.searchHistory.allSearchesChronologically

        try #require(entries1.count == 1)
        #expect(entries1[0].lastUsedAt == firstDate)

        try db.searchHistory.recordSearch(with: filters, at: secondDate)
        let entries2 = try db.searchHistory.allSearchesChronologically

        try #require(entries2.count == 1)
        #expect(entries2[0].lastUsedAt == secondDate)
    }

    @Test("deletes a complete search from history")
    func deleteCompleteSearch() throws {
        let db = try SQLiteDatabase.initialize()
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        try db.searchHistory.recordSearch(with: firstSearch)
        try db.searchHistory.recordSearch(with: secondSearch)

        var entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 2)

        try db.searchHistory.deleteSearch(with: firstSearch)

        entries = try db.searchHistory.allSearchesChronologically
        try #require(entries.count == 1)
        #expect(entries[0].search == secondSearch)
    }

    @Test("does nothing when deleting a nonexistent complete search")
    func deleteNonexistentCompleteSearch() throws {
        let db = try SQLiteDatabase.initialize()
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        try db.searchHistory.recordSearch(with: firstSearch)

        try db.searchHistory.deleteSearch(with: secondSearch)

        let entries = try db.searchHistory.allSearchesChronologically
        try #require(entries.count == 1)
        #expect(entries[0].search == firstSearch)
    }

    @Test("sorted search history returns entries in reverse chronological order")
    func sortedSearchHistory() throws {
        let db = try SQLiteDatabase.initialize()
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]
        let thirdSearch = [SearchFilter.basic(false, "set", .equal, "ody")]

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1120) // 2 minutes later
        let thirdDate = Date(timeIntervalSinceReferenceDate: 1240) // 4 minutes from start

        try db.searchHistory.recordSearch(with: firstSearch, at: firstDate)
        try db.searchHistory.recordSearch(with: thirdSearch, at: thirdDate)
        // Out of order!
        try db.searchHistory.recordSearch(with: secondSearch, at: secondDate)

        let sorted = try db.searchHistory.allSearchesChronologically

        try #require(sorted.count == 3)
        #expect(sorted[0].search == thirdSearch)
        #expect(sorted[1].search == secondSearch)
        #expect(sorted[2].search == firstSearch)
    }

    @Test("distinguishes between different searches with multiple filters")
    func multipleComplexSearches() throws {
        let db = try SQLiteDatabase.initialize()
        let firstSearch = [
            SearchFilter.basic(false, "color", .equal, "red"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]
        let secondSearch = [
            SearchFilter.basic(false, "color", .equal, "blue"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1060) // 60 seconds later
        
        try db.searchHistory.recordSearch(with: firstSearch, at: firstDate)
        try db.searchHistory.recordSearch(with: secondSearch, at: secondDate)

        let entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 2)
        #expect(entries[0].search == secondSearch)
        #expect(entries[1].search == firstSearch)
    }

    // MARK: - Garbage Collection Tests

    @Test("garbage collection removes searches beyond hard limit")
    func garbageCollectHardLimit() throws {
        let db = try SQLiteDatabase.initialize()

        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]
        let thirdSearch = [SearchFilter.basic(false, "set", .equal, "ody")]

        let firstDate = Date(timeIntervalSinceReferenceDate: 1000)
        let secondDate = Date(timeIntervalSinceReferenceDate: 1090) // 90 seconds later
        let thirdDate = Date(timeIntervalSinceReferenceDate: 1180) // 3 minutes from start

        try db.searchHistory.recordSearch(with: firstSearch, at: firstDate)
        try db.searchHistory.recordSearch(with: thirdSearch, at: thirdDate)
        // Out of order!
        try db.searchHistory.recordSearch(with: secondSearch, at: secondDate)

        var entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 3)

        try db.searchHistory.garbageCollect(hardLimit: 2, softLimit: 1, cutoffDate: Date(timeIntervalSinceReferenceDate: 0))

        entries = try db.searchHistory.allSearchesChronologically
        try #require(entries.count == 1)
        #expect(entries[0].search == thirdSearch)
    }

    @Test("garbage collection preserves searches below hard limit")
    func garbageCollectBelowHardLimit() throws {
        let db = try SQLiteDatabase.initialize()

        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        try db.searchHistory.recordSearch(with: firstSearch)
        try db.searchHistory.recordSearch(with: secondSearch)

        var entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 2)

        try db.searchHistory.garbageCollect(hardLimit: 10, softLimit: 5, cutoffDate: Date(timeIntervalSinceReferenceDate: 0))

        entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 2)
    }

    @Test("garbage collection removes old searches")
    func garbageCollectOldSearches() throws {
        let db = try SQLiteDatabase.initialize()
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        let date = Date(timeIntervalSinceReferenceDate: 1000)

        try db.searchHistory.recordSearch(with: firstSearch, at: date)
        try db.searchHistory.recordSearch(with: secondSearch, at: date)

        var entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.count == 2)

        // Garbage collect with cutoff date right now should delete everything.
        try db.searchHistory.garbageCollect(cutoffDate: Date())

        entries = try db.searchHistory.allSearchesChronologically
        #expect(entries.isEmpty)
    }
}


