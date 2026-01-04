import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
class HistoryAndPinnedStoreTests {
    @Dependency(\.defaultDatabase) var database
    var store: HistoryAndPinnedStore!

    init() throws {
        store = HistoryAndPinnedStore(database: database)
    }
    
    // MARK: - Utility Properties
    
    private var allSearchHistory: [SearchHistoryEntry] {
        get throws {
            try database.read { db in
                try SearchHistoryEntry.order { $0.lastUsedAt.desc() }.fetchAll(db)
            }
        }
    }
    
    private var allFilterHistory: [FilterHistoryEntry] {
        get throws {
            try database.read { db in
                try FilterHistoryEntry.order { $0.lastUsedAt.desc() }.fetchAll(db)
            }
        }
    }
    
    private var allPinnedFilters: [PinnedFilterEntry] {
        get throws {
            try database.read { db in
                try PinnedFilterEntry.order { $0.pinnedAt.desc() }.fetchAll(db)
            }
        }
    }

    // MARK: - Complete Search Entry Tests

    @Test("records a search itself as well as the consituent filters")
    func recordCompleteSearch() throws {
        let filters = [
            SearchFilter.basic(false, "color", .equal, "red"),
            SearchFilter.basic(false, "oracle", .including, "flying"),
        ]

        store.record(search: filters)

        let entries = try allSearchHistory
        try #require(entries.count == 1)
        #expect(entries[0].filters == filters)
        
        let filterEntries = try allFilterHistory
        try #require(filterEntries.count == 2)
        #expect(filterEntries.map(\.filter) == filters)
    }

    @Test("updates last used date of a filter when it appears in a later search")
    func updateExistingSearch() throws {
        let sharedFilter = SearchFilter.basic(false, "color", .equal, "red")
        let uniqueFilter1 = SearchFilter.basic(false, "oracle", .including, "flying")
        let uniqueFilter2 = SearchFilter.basic(false, "set", .equal, "ody")
        
        let search1 = [sharedFilter, uniqueFilter1]
        let search2 = [sharedFilter, uniqueFilter2]

        let date1 = Date(timeIntervalSinceReferenceDate: 1000)
        let date2 = Date(timeIntervalSinceReferenceDate: 2000)

        store.record(search: search1, at: date1)
        
        let entries1 = try allFilterHistory
        try #require(entries1.count == 2)

        store.record(search: search2, at: date2)
        
        let entries2 = try allFilterHistory
        try #require(entries2.count == 3)
        
        #expect(entries2.map(\.filter) == [sharedFilter, uniqueFilter2, uniqueFilter1])
        #expect(entries2.map(\.lastUsedAt) == [date2, date2, date1])
    }

    @Test("deleting a search takes effect, but does not delete the constituent filters")
    func deleteCompleteSearch() throws {
        let search1 = [SearchFilter.basic(false, "color", .equal, "red")]
        let search2 = [SearchFilter.basic(false, "oracle", .including, "flying")]

        store.record(search: search1)
        store.record(search: search2)

        var entries = try allSearchHistory
        #expect(entries.count == 2)
        
        let filterEntries1 = try allFilterHistory
        #expect(filterEntries1.count == 2)

        store.delete(search: search1)

        entries = try allSearchHistory
        try #require(entries.count == 1)
        #expect(entries[0].filters == search2)
        
        let filterEntries2 = try allFilterHistory
        #expect(filterEntries2.count == 2)
    }

    @Test("does nothing when deleting a nonexistent search")
    func deleteNonexistentCompleteSearch() throws {
        let search1 = [SearchFilter.basic(false, "color", .equal, "red")]
        let search2 = [SearchFilter.basic(false, "oracle", .including, "flying")]

        store.record(search: search1)
        
        let entries1 = try allSearchHistory
        #expect(entries1.count == 1)
        
        store.delete(search: search2)

        let entries2 = try allSearchHistory
        #expect(entries2.count == 1)
        #expect(entries2[0].filters == search1)
    }

    @Test("pinning a filter adds it to the list, unpinning removes it")
    func pinAndUnpinFilter() throws {
        let filter = SearchFilter.basic(false, "color", .equal, "red")

        var pinned = try allPinnedFilters
        #expect(pinned.count == 0)

        store.pin(filter: filter)

        pinned = try allPinnedFilters
        try #require(pinned.count == 1)
        #expect(pinned[0].filter == filter)

        store.unpin(filter: filter)

        pinned = try allPinnedFilters
        #expect(pinned.count == 0)
    }

    @Test("when deleting a pinned filter, it is also removed from the pinned list")
    func deletePinnedFilter() throws {
        let filter = SearchFilter.basic(false, "color", .equal, "red")

        store.record(search: [filter])
        store.pin(filter: filter)

        var filterEntries = try allFilterHistory
        #expect(filterEntries.count == 1)

        var pinned = try allPinnedFilters
        #expect(pinned.count == 1)

        store.delete(filter: filter)

        filterEntries = try allFilterHistory
        #expect(filterEntries.count == 0)

        pinned = try allPinnedFilters
        #expect(pinned.count == 0)
    }
}


