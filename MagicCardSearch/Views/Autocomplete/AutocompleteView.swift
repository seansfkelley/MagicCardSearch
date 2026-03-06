import SwiftUI

struct AutocompleteView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    @Binding var searchState: SearchState

    @State private var suggestions: [Suggestion2] = []
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
        .notEqual,
    ]

    var body: some View {
        List {
            if let filter = searchState.searchText.toFilter().value {
                Button {
                    addTopLevelFilter(filter)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        Text(filter.description)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
                suggestionRow(suggestion)
                    .listRowInsets(.vertical, 0)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .task(id: searchSuggestionKey) {
            for await newSuggestions in searchState.suggestionProvider.getSuggestions(
                for: searchState.selectedFilter.text,
                existingFilters: Set(searchState.filters),
            ) {
                suggestions = newSuggestions
            }
        }
    }

    // MARK: - Row Selection

    @ViewBuilder
    private func suggestionRow(_ suggestion: Suggestion2) -> some View {
        switch suggestion.content {
        case .filter:
            filterRow(suggestion)
        case .filterType:
            FilterTypeRowView(
                suggestion: suggestion,
                orderedAllComparisons: orderedAllComparisons,
                orderedEqualityComparison: orderedEqualityComparison,
                onSelect: setScopedString
            )
        case .filterParts:
            FilterPartsRowView(
                suggestion: suggestion,
                onSelect: { addScopedFilter(.term($0)) }
            )
        }
    }

    @ViewBuilder
    private func filterRow(_ suggestion: Suggestion2) -> some View {
        let row = BasicRowView(suggestion: suggestion) { filter in
            if suggestion.source == .name {
                addTopLevelFilter(filter)
                searchState.performSearch()
            } else {
                addScopedFilter(filter)
            }
        }

        switch suggestion.source {
        case .pinnedFilter:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let highlighted) = suggestion.content {
                        Button {
                            historyAndPinnedStore.unpin(filter: highlighted.value)
                            nonce += 1
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if case .filter(let highlighted) = suggestion.content {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: highlighted.value)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        case .historyFilter:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let highlighted) = suggestion.content {
                        pinSwipeAction(for: highlighted.value)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if case .filter(let highlighted) = suggestion.content {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: highlighted.value)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        case .enumeration:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let highlighted) = suggestion.content {
                        pinSwipeAction(for: highlighted.value)
                    }
                }
        default:
            row
        }
    }

    // MARK: - Actions

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

extension Suggestion2 {
    var icon: String {
        switch source {
        case .pinnedFilter: "pin.fill"
        case .historyFilter: "clock.arrow.circlepath"
        case .filterType: "line.3.horizontal.decrease.circle"
        case .enumeration: "list.bullet.circle"
        case .reverseEnumeration: "line.3.horizontal.decrease.circle"
        case .name: "textformat.abc"
        }
    }
}
