//
//  SearchHistoryTrackerTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//

import Testing
import Foundation
@testable import MagicCardSearch

@Suite
class SearchHistoryTrackerTests {
    // MARK: - Filter Entry Tests

    @Test("records usage of a single filter")
    func recordFilterUsage() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")

        tracker.recordUsage(of: colorFilter)

        #expect(tracker.filterEntries.count == 1)
        #expect(tracker.filterEntries[colorFilter] != nil)
    }

    @Test("updates last used date when recording usage of an existing filter")
    func updateExistingFilter() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")

        tracker.recordUsage(of: colorFilter)
        let firstDate = tracker.filterEntries[colorFilter]?.lastUsedDate

        // Small delay to ensure different timestamps
        Thread.sleep(forTimeInterval: 0.01)

        tracker.recordUsage(of: colorFilter)
        let secondDate = tracker.filterEntries[colorFilter]?.lastUsedDate

        #expect(firstDate != nil)
        #expect(secondDate != nil)
        #expect(secondDate! > firstDate!)
    }

    @Test("deletes a filter from history")
    func deleteFilter() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        tracker.recordUsage(of: colorFilter)
        tracker.recordUsage(of: oracleFilter)

        #expect(tracker.filterEntries.count == 2)

        tracker.delete(filter: colorFilter)

        #expect(tracker.filterEntries.count == 1)
        #expect(tracker.filterEntries[colorFilter] == nil)
        #expect(tracker.filterEntries[oracleFilter] != nil)
    }

    @Test("does nothing when deleting a nonexistent filter")
    func deleteNonexistentFilter() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        tracker.recordUsage(of: colorFilter)

        tracker.delete(filter: oracleFilter)

        #expect(tracker.filterEntries.count == 1)
        #expect(tracker.filterEntries[colorFilter] != nil)
    }

    @Test("sorted filter history returns entries in reverse chronological order")
    func sortedFilterHistory() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")

        tracker.recordUsage(of: colorFilter)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: oracleFilter)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: setFilter)

        let sorted = tracker.sortedFilterHistory

        #expect(sorted.count == 3)
        #expect(sorted[0].filter == setFilter)
        #expect(sorted[1].filter == oracleFilter)
        #expect(sorted[2].filter == colorFilter)
    }

    // MARK: - Complete Search Entry Tests

    @Test("records usage of a complete search")
    func recordCompleteSearch() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let filters = [
            SearchFilter.basic(false, "color", .equal, "red"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]

        tracker.recordUsage(of: filters)

        #expect(tracker.completeSearchEntries.count == 1)
        #expect(tracker.completeSearchEntries[0].filters == filters)
    }

    @Test("moves existing complete search to front when recorded again")
    func recordExistingCompleteSearch() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        tracker.recordUsage(of: firstSearch)
        tracker.recordUsage(of: secondSearch)

        #expect(tracker.completeSearchEntries.count == 2)
        #expect(tracker.completeSearchEntries[0].filters == secondSearch)

        tracker.recordUsage(of: firstSearch)

        #expect(tracker.completeSearchEntries.count == 2)
        #expect(tracker.completeSearchEntries[0].filters == firstSearch)
        #expect(tracker.completeSearchEntries[1].filters == secondSearch)
    }

    @Test("deletes a complete search from history")
    func deleteCompleteSearch() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        tracker.recordUsage(of: firstSearch)
        tracker.recordUsage(of: secondSearch)

        #expect(tracker.completeSearchEntries.count == 2)

        tracker.delete(filters: firstSearch)

        #expect(tracker.completeSearchEntries.count == 1)
        #expect(tracker.completeSearchEntries[0].filters == secondSearch)
    }

    @Test("does nothing when deleting a nonexistent complete search")
    func deleteNonexistentCompleteSearch() {
        let tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]

        tracker.recordUsage(of: firstSearch)

        tracker.delete(filters: secondSearch)

        #expect(tracker.completeSearchEntries.count == 1)
        #expect(tracker.completeSearchEntries[0].filters == firstSearch)
    }

    // MARK: - Garbage Collection Tests

    @Test("garbage collection removes filters beyond hard limit")
    func garbageCollectHardLimit() {
        let tracker = SearchHistoryTracker(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")

        tracker.recordUsage(of: colorFilter)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: oracleFilter)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: setFilter)

        #expect(tracker.filterEntries.count == 3)

        tracker.maybeGarbageCollectHistory()

        // Should trim down to softLimit (1)
        #expect(tracker.filterEntries.count == 1)
        // Should keep the most recent one
        #expect(tracker.filterEntries[setFilter] != nil)
    }

    @Test("garbage collection preserves filters below hard limit")
    func garbageCollectBelowHardLimit() {
        let tracker = SearchHistoryTracker(
            hardLimit: 10,
            softLimit: 5,
            persistenceKey: UUID().uuidString
        )

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")

        tracker.recordUsage(of: colorFilter)
        tracker.recordUsage(of: oracleFilter)

        #expect(tracker.filterEntries.count == 2)

        tracker.maybeGarbageCollectHistory()

        #expect(tracker.filterEntries.count == 2)
    }

    @Test("garbage collection removes complete searches beyond hard limit")
    func garbageCollectCompleteSearchesHardLimit() {
        let tracker = SearchHistoryTracker(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )

        let firstSearch = [SearchFilter.basic(false, "color", .equal, "red")]
        let secondSearch = [SearchFilter.basic(false, "oracle", .including, "flying")]
        let thirdSearch = [SearchFilter.basic(false, "set", .equal, "ody")]

        tracker.recordUsage(of: firstSearch)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: secondSearch)
        Thread.sleep(forTimeInterval: 0.01)
        tracker.recordUsage(of: thirdSearch)

        #expect(tracker.completeSearchEntries.count == 3)

        tracker.maybeGarbageCollectHistory()

        // Should trim down to softLimit (1)
        #expect(tracker.completeSearchEntries.count == 1)
        // Should keep the most recent one
        #expect(tracker.completeSearchEntries[0].filters == thirdSearch)
    }
}
