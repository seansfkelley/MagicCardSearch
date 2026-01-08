import Foundation
import SQLiteData
import Observation

struct HistorySuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

@Observable
class HistorySuggestionProvider {
    // MARK: - Properties

    @ObservationIgnored
    @FetchAll(FilterHistoryEntry.order { $0.lastUsedAt.desc() })
    // swiftlint:disable:next attributes
    private var filterHistoryEntries

    @ObservationIgnored
    @FetchAll(SearchHistoryEntry.order { $0.lastUsedAt.desc() })
    // swiftlint:disable:next attributes
    private var searchHistoryEntries

    // MARK: - Public Methods

    func getSuggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [HistorySuggestion] {
        guard limit > 0 else {
            return []
        }
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

        return Array(
            filterHistoryEntries
                .lazy
                .filter { !excludedFilters.contains($0.filter) }
                .compactMap { entry in
                    let filterText = entry.filter.description

                    if trimmedSearchTerm.isEmpty {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil,
                            // TODO: Would .actual produce better results?
                            prefixKind: .none,
                            suggestionLength: filterText.count,
                        )
                    }
                    
                    if let range = filterText.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: range,
                            prefixKind: range.lowerBound == filterText.startIndex ? .actual : .none,
                            suggestionLength: filterText.count,
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }
}
