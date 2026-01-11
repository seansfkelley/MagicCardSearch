import SwiftUI

struct AutocompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    @Binding var searchState: SearchState
    @Binding var suggestionLoadingState: DebouncedLoadingState

    @State private var suggestions: [Suggestion] = []
    @State private var nonce: Int = 0

    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(inputText: searchState.searchText, filterCount: searchState.filters.count, nonce: nonce)
    }

    private struct SearchSuggestionKey: Equatable {
        // Obvious.
        let inputText: String
        // This allows the history autocomplete to hide ones you pick. In the future, it might be
        // used for other autocompletes that read your existing filters.
        let filterCount: Int
        // This is a proxy for the value we actually care about: did you perform a search?
        // Performing a search commits all the filters to history, meaning that the history provider
        // now has more options. Instead of watching did-search directly, we just watch for times
        // that the search bar gained focus, which is when we actually need to recalculate.
        //
        // This nonce is also used whenever pinning changes, which can trigger different suggestions.
        let nonce: Int
    }

    private let orderedEqualityComparison: [Comparison] = [
        .including,
        .equal,
    ]

    private let orderedAllComparisons: [Comparison] = [
        .including,
        .equal,
        .lessThan,
        .lessThanOrEqual,
        .greaterThanOrEqual,
        .greaterThan,
        .notEqual, // n.b. this only works for some orderable things; equality-only things require the negation syntax
    ]

    var body: some View {
        List {
            if let filter = searchState.searchText.toFilter().value {
                BasicRowView(
                    filter: filter,
                    matchRange: nil,
                    systemImageName: "magnifyingglass",
                ) { addTopLevelFilter($0) }
            }

            ForEach(suggestions, id: \.self) { suggestion in
                switch suggestion {
                case .pinned(let suggestion):
                    BasicRowView(
                        filter: suggestion.filter,
                        matchRange: suggestion.matchRange,
                        systemImageName: "pin.fill",
                    ) { addScopedFilter($0) }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            historyAndPinnedStore.unpin(filter: suggestion.filter)
                            nonce += 1
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: suggestion.filter)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowInsets(.vertical, 0)
                case .filterHistory(let suggestion):
                    BasicRowView(
                        filter: suggestion.filter,
                        matchRange: suggestion.matchRange,
                        systemImageName: "clock.arrow.circlepath",
                    ) { addScopedFilter($0) }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        pinSwipeAction(for: suggestion.filter)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: suggestion.filter)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .listRowInsets(.vertical, 0)

                case .filter(let suggestion):
                    FilterTypeRowView(
                        suggestion: suggestion,
                        orderedAllComparisons: orderedAllComparisons,
                        orderedEqualityComparison: orderedEqualityComparison,
                        onSelect: setScopedString
                    )
                    .listRowInsets(.vertical, 0)

                case .enumeration(let suggestion):
                    BasicRowView(
                        filter: .term(suggestion.filter),
                        matchRange: suggestion.matchRange,
                        systemImageName: "list.bullet.circle",
                    ) { addScopedFilter($0) }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        pinSwipeAction(for: .term(suggestion.filter))
                    }
                    .listRowInsets(.vertical, 0)

                case .reverseEnumeration(let suggestion):
                    ReverseEnumerationRowView(
                        suggestion: suggestion,
                        onSelect: { addScopedFilter(.term($0)) }
                    )
                    .listRowInsets(.vertical, 0)

                case .name(let suggestion):
                    BasicRowView(
                        filter: .term(suggestion.filter),
                        matchRange: suggestion.matchRange,
                        systemImageName: "textformat.abc",
                    ) {
                        // We don't replace the entire search because some other filters might
                        // actually have an effect on the results, like `set:`.
                        addTopLevelFilter($0)
                        searchState.performSearch()
                    }
                    .listRowInsets(.vertical, 0)
                }
            }
        }
        .listStyle(.plain)
        .task(id: searchSuggestionKey) {
            for await newSuggestions in searchState.suggestionProvider.getSuggestions(
                for: searchState.selectedFilter.text,
                existingFilters: Set(searchState.filters),
            ) {
                suggestions = newSuggestions
            }
        }
    }

    private func setEntireSearch(to search: [FilterQuery<FilterTerm>]) {
        searchState.filters = search
        searchState.searchText = ""
        searchState.desiredSearchSelection = nil
        searchState.performSearch()
    }

    private func addTopLevelFilter(_ filter: FilterQuery<FilterTerm>) {
        searchState.filters.append(filter)
        searchState.searchText = ""
        searchState.desiredSearchSelection = nil
    }

    private func addScopedFilter(_ filter: FilterQuery<FilterTerm>) {
        if let range = searchState.selectedFilter.range, range != searchState.searchText.range {
            let filterString = filter.description
            if range.upperBound == searchState.searchText.endIndex {
                searchState.searchText.replaceSubrange(range, with: filterString)
                searchState.desiredSearchSelection = nil
            } else {
                searchState.searchText.replaceSubrange(range, with: filterString)
                let index = searchState.searchText.index(range.lowerBound, offsetBy: filterString.count)
                searchState.desiredSearchSelection = .init(insertionPoint: index)
            }
        } else {
            searchState.filters.append(filter)
            searchState.searchText = ""
            searchState.desiredSearchSelection = nil
        }
    }

    private func setScopedString(_ string: String) {
        if let range = searchState.selectedFilter.range {
            searchState.searchText.replaceSubrange(range, with: string)
            let index = searchState.searchText.index(range.lowerBound, offsetBy: string.count)
            searchState.desiredSearchSelection = .init(insertionPoint: index)
        } else {
            searchState.searchText = string
            searchState.desiredSearchSelection = nil
        }
    }

    @ViewBuilder
    private func pinSwipeAction(for filter: FilterQuery<FilterTerm>) -> some View {
        Button {
            historyAndPinnedStore.pin(filter: filter)
            nonce += 1
        } label: {
            Label("Pin", systemImage: "pin")
        }
        .tint(.orange)
    }
}
