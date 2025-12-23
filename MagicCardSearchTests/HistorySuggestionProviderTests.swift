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
    var tracker: SearchHistoryTracker

    init() {
        tracker = SearchHistoryTracker(persistenceKey: UUID().uuidString)
        provider = HistorySuggestionProvider(with: tracker)
    }

    private func recordUsages(of filters: [SearchFilter]) {
        for filter in filters {
            tracker.recordUsage(of: filter)
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
        #expect(suggestions == [.init(filter: oracleFilter, matchRange: nil)])
    }

    @Test("should not delete any filters if the soft limit but not the hard limit is reached")
    func testSoftLimit() {
        tracker = SearchHistoryTracker(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )
        provider = HistorySuggestionProvider(with: tracker)

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        recordUsages(of: [colorFilter, oracleFilter])

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: oracleFilter, matchRange: nil),
            .init(filter: colorFilter, matchRange: nil),
        ])
    }

    @Test("deletes the oldest filters beyond the soft limit if the hard limit is reached")
    func testHardLimit() {
        tracker = SearchHistoryTracker(
            hardLimit: 2,
            softLimit: 1,
            persistenceKey: UUID().uuidString
        )
        provider = HistorySuggestionProvider(with: tracker)

        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "ody")
        recordUsages(of: [colorFilter, oracleFilter, setFilter])

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: nil),
        ])
    }

    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        let setFilter = SearchFilter.basic(false, "set", .equal, "odyssey")
        recordUsages(of: [colorFilter, oracleFilter, setFilter])

        let suggestions = provider.getSuggestions(for: "y", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: "set:odyssey".range(of: "y")),
            .init(filter: oracleFilter, matchRange: "oracle:flying".range(of: "y")),
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
            .init(filter: setFilter, matchRange: "set:ody".range(of: "y")),
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
    func deleteNonexistent() {
        let colorFilter = SearchFilter.basic(false, "color", .equal, "red")
        let oracleFilter = SearchFilter.basic(false, "oracle", .including, "flying")
        recordUsages(of: [colorFilter])

        tracker.delete(filter: oracleFilter)

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions == [.init(filter: colorFilter, matchRange: nil)])
    }
}
