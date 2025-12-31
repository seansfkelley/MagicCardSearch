//
//  HistorySuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//

import Testing
import Foundation
@testable import MagicCardSearch

@Suite
class HistorySuggestionProviderTests {
    var provider: HistorySuggestionProvider
    var db: SQLiteDatabase

    init() throws {
        db = try SQLiteDatabase.initialize()
        provider = HistorySuggestionProvider(
            filterHistoryStore: db.filterHistory,
            searchHistoryStore: db.searchHistory
        )
    }

    private func recordUsages(of filters: [SearchFilter]) {
        for filter in filters {
            try? db.filterHistory.recordUsage(of: filter)
        }
    }

    // MARK: - Basic Functionality Tests

    @Test("empty provider returns no suggestions")
    func emptySuggestions() {
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }

    @Test("returns all filters below the limit if no search term is provided")
    func emptySearchText() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        recordUsages(of: [colorFilter, oracleFilter])

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 1)
        // Prefers the latter, because it was recorded later.
        #expect(suggestions == [.init(filter: oracleFilter, matchRange: nil, prefixKind: .none, suggestionLength: 13)])
    }

    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "odyssey")
        recordUsages(of: [colorFilter, oracleFilter, setFilter])

        let suggestions = provider.getSuggestions(for: "y", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: "set:odyssey".range(of: "y"), prefixKind: .none, suggestionLength: 11),
            .init(filter: oracleFilter, matchRange: "oracle:flying".range(of: "y"), prefixKind: .none, suggestionLength: 13),
        ])
    }

    @Test("returns exclude matching filters present in the exclusion list")
    func excludeMatchingFilters() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")
        recordUsages(of: [colorFilter, oracleFilter, setFilter])

        let suggestions = provider.getSuggestions(for: "y", excluding: Set([oracleFilter]), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: "set:ody".range(of: "y"), prefixKind: .none, suggestionLength: 7),
        ])
    }

    @Test("returns the empty list if there is no simple substring match in the stringified filters")
    func noSubstringMatch() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        recordUsages(of: [colorFilter, oracleFilter])

        let suggestions = provider.getSuggestions(for: "xyz", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }

    @Test("does nothing if deleting a filter that does not exist")
    func deleteNonexistent() throws {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        recordUsages(of: [colorFilter])

        try db.filterHistory.deleteUsage(of: oracleFilter)

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [.init(filter: colorFilter, matchRange: nil, prefixKind: .none, suggestionLength: 9)])
    }
}
