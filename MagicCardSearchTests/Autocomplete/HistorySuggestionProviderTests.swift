import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
class HistorySuggestionProviderTests {
    @Dependency(\.defaultDatabase) var database

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

    private func fetchHistory() -> [FilterHistoryEntry] {
        try! database.read { db in
            try FilterHistoryEntry
                .order { $0.lastUsedAt.desc() }
                .fetchAll(db)
        }
    }

    private func extractFilters(_ suggestions: [Suggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    // MARK: - Basic Functionality Tests

    @Test("returns no results with no history recorded")
    func emptySuggestions() {
        let suggestions = filterHistorySuggestions(for: "", from: fetchHistory(), limit: 10)
        #expect(suggestions.isEmpty)
    }

    @Test("returns all filters below the limit if no search term is provided")
    func emptySearchText() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        let suggestions = filterHistorySuggestions(for: "", from: fetchHistory(), limit: 1)
        let filters = extractFilters(suggestions)
        #expect(filters == [oracleFilter])
    }

    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
        let setFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "set", .equal, "odyssey"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)
        record(filter: setFilter, atOffset: 2000)

        let suggestions = filterHistorySuggestions(for: "y", from: fetchHistory(), limit: 10)
        let filters = extractFilters(suggestions)
        #expect(filters == [setFilter, oracleFilter])
    }

    @Test("returns the empty list if there is no simple substring match in the stringified filters")
    func noSubstringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        let suggestions = filterHistorySuggestions(for: "xyz", from: fetchHistory(), limit: 10)
        #expect(suggestions.isEmpty)
    }
}
