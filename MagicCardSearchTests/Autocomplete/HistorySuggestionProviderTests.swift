import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
class HistorySuggestionProviderTests {
    @Dependency(\.defaultDatabase) var database
    var provider: FilterHistorySuggestionProvider

    init() throws {
        provider = FilterHistorySuggestionProvider()
    }

    private func record(filter: FilterQuery<FilterTerm>, atOffset interval: TimeInterval) {
        try? database.write { db in
            try FilterHistoryEntry
                .insert {
                    FilterHistoryEntry(
                        filter: filter,
                        at: Date(timeIntervalSinceReferenceDate: interval),
                    )
                }
                .execute(db)
        }
    }

    private func wait() {
        // Allow triggers to fire and for the provider's queries to refresh themselves. In a real
        // app it really doesn't matter that there is this reactive delay, but in tests we go too
        // fast!
        Thread.sleep(forTimeInterval: 0.1)
    }

    // MARK: - Basic Functionality Tests

    @Test("returns no results with no history recorded")
    func emptySuggestions() {
        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }

    @Test("returns all filters below the limit if no search term is provided")
    func emptySearchText() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        wait()

        let suggestions = provider.getSuggestions(for: "", excluding: Set(), limit: 1)
        // Prefers the latter, because it was recorded later.
        #expect(suggestions == [.init(filter: oracleFilter, matchRange: nil, prefixKind: .none, suggestionLength: 13)])
    }

    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
        let setFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "set", .equal, "odyssey"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)
        record(filter: setFilter, atOffset: 2000)

        wait()

        let suggestions = provider.getSuggestions(for: "y", excluding: Set(), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: "set:odyssey".range(of: "y"), prefixKind: .none, suggestionLength: 11),
            .init(filter: oracleFilter, matchRange: "oracle:flying".range(of: "y"), prefixKind: .none, suggestionLength: 13),
        ])
    }

    @Test("returns exclude matching filters present in the exclusion list")
    func excludeMatchingFilters() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
        let setFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "set", .equal, "ody"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)
        record(filter: setFilter, atOffset: 2000)

        wait()

        let suggestions = provider.getSuggestions(for: "y", excluding: Set([oracleFilter]), limit: 10)
        #expect(suggestions == [
            .init(filter: setFilter, matchRange: "set:ody".range(of: "y"), prefixKind: .none, suggestionLength: 7),
        ])
    }

    @Test("returns the empty list if there is no simple substring match in the stringified filters")
    func noSubstringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        wait()

        let suggestions = provider.getSuggestions(for: "xyz", excluding: Set(), limit: 10)
        #expect(suggestions.isEmpty)
    }
}
