import Foundation
import SQLiteData
import Observation

struct SearchHistorySuggestion: Equatable, Hashable, Sendable {
    let filters: [FilterMatch]

    // Workaround for Swift not being able to synthesize basic protocol conformances for tuples.
    struct FilterMatch: Hashable, Equatable, Sendable {
        let filter: FilterQuery<FilterTerm>
        let kind: MatchKind

        init(_ filter: FilterQuery<FilterTerm>, _ kind: MatchKind) {
            self.filter = filter
            self.kind = kind
        }
    }

    enum MatchKind: Hashable, Equatable, Sendable {
        case complete, none
        case substring(Range<String.Index>)
    }
}

@Observable
class SearchHistorySuggestionProvider {
    // MARK: - Properties

    @ObservationIgnored
    @FetchAll(SearchHistoryEntry.order { $0.lastUsedAt.desc() })
    private var searchHistoryEntries

    // MARK: - Public Methods

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>, limit: Int) -> [SearchHistorySuggestion] {
        guard limit > 0 else {
            return []
        }

        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

        return Array(
            searchHistoryEntries
                .lazy
                .filter { entry in
                    existingFilters.isEmpty || existingFilters.allSatisfy { entry.filters.contains($0) }
                }
                .compactMap { entry in
                    if trimmedSearchTerm.isEmpty {
                        return SearchHistorySuggestion(
                            filters: entry.filters.map { .init($0, .none) }
                        )
                    } else {
                        let matchedFilters = entry.filters.map { filter -> SearchHistorySuggestion.FilterMatch in
                            if existingFilters.contains(filter) {
                                .init(filter, .complete)
                            } else if let range = filter.description.range(of: trimmedSearchTerm) {
                                .init(filter, .substring(range))
                            } else {
                                .init(filter, .none)
                            }
                        }

                        return if matchedFilters.contains(where: { if case .substring = $0.kind { true } else { false } }) {
                            SearchHistorySuggestion(
                                filters: matchedFilters
                            )
                        } else {
                            nil
                        }
                    }
                }
                .prefix(limit)
        )
    }
}
