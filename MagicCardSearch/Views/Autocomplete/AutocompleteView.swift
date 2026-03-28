import SwiftUI

struct AutocompleteView: View {
    @ScaledMetric private var iconWidth = AutocompleteConstants.defaultSuggestionIconWidth
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    @Binding var searchState: SearchState

    @State private var suggestions: [AutocompleteSuggestion] = []
    @State private var nonce: Int = 0

    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(
            inputText: searchState.searchText,
            filterCount: searchState.filters.count,
            currentFilterRange: searchState.selectedFilter.range,
            nonce: nonce,
        )
    }

    private struct SearchSuggestionKey: Equatable {
        // Obvious.
        let inputText: String
        // After you add/remove a filter, we may hide or show certain other suggestions.
        let filterCount: Int
        // Dragging the selection around may change the suggestions, if you are editing a string
        // with multiple subfilters. This is the range of the current filter, if any, not the
        // literal selection range, so it only changes when the user hovers to another filter.
        let currentFilterRange: Range<String.Index>?
        // This is a proxy for the value we actually care about: did you perform a search?
        // Performing a search commits all the filters to history, meaning that the history provider
        // now has more options. Instead of watching did-search directly, we just watch for times
        // that the search bar gained focus, which is when we actually need to recalculate.
        //
        // This nonce is also used whenever pinning changes, which can trigger different suggestions.
        let nonce: Int
    }

    private enum AddedFilterResult {
        case text, filter
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
            if let filter = PartialFilterQuery.from(searchState.searchText, autoclosePairedDelimiters: true).value?.transformLeaves(using: FilterTerm.from) {
                Button {
                    searchState.filters.append(filter)
                    searchState.searchText = ""
                    searchState.desiredSearchSelection = nil
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                            .font(.system(size: AutocompleteSuggestion.defaultIconFontSize))
                            .frame(width: iconWidth)
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
            guard let newSuggestions = try? await searchState.getSuggestions() else { return }
            guard !Task.isCancelled else { return }
            suggestions = newSuggestions
        }
    }

    // MARK: - Row Selection

    @ViewBuilder
    private func suggestionRow(_ suggestion: AutocompleteSuggestion) -> some View {
        switch suggestion.content {
        case .filter:
            filterRow(suggestion)
        case .filterType:
            FilterTypeRowView(
                suggestion: suggestion,
                orderedAllComparisons: orderedAllComparisons,
                orderedEqualityComparison: orderedEqualityComparison,
            ) { setFilterString($0) }
        case .filterParts(let polarity, let filterType, let value):
            FilterPartsRowView(suggestion: suggestion) { addFilter(.term($0)) }
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    pinSwipeAction(for: .term(.basic(polarity, filterType.canonicalName, .including, value.value)))
                }
        }
    }

    @ViewBuilder
    private func filterRow(_ suggestion: AutocompleteSuggestion) -> some View {
        let shouldSearchImmediately = suggestion.source == .name && searchState.selectedFilter.scopedRange == nil

        let row = FilterRowView(
            suggestion: suggestion,
            showImmediateSearchIcon: shouldSearchImmediately,
        ) { filter in
            // Belt-and-suspenders to make sure we don't search immediately if we somehow only ended
            // up modifying the search text.
            if addFilter(filter) == .filter && shouldSearchImmediately {
                searchState.performSearch()
            }
        }

        switch suggestion.source {
        case .pinnedFilter:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let match) = suggestion.content {
                        Button {
                            historyAndPinnedStore.unpin(filter: match.value)
                            nonce += 1
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .tint(.orange)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if case .filter(let match) = suggestion.content {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: match.value)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        case .historyFilter:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let match) = suggestion.content {
                        pinSwipeAction(for: match.value)
                    }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if case .filter(let match) = suggestion.content {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(filter: match.value)
                            nonce += 1
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
        case .enumeration:
            row
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                    if case .filter(let match) = suggestion.content {
                        pinSwipeAction(for: match.value)
                    }
                }
        default:
            row
        }
    }

    // MARK: - Actions

    @discardableResult
    private func addFilter(_ filter: FilterQuery<FilterTerm>) -> AddedFilterResult {
        if let range = searchState.selectedFilter.scopedRange {
            let filterString = filter.description
            if range.upperBound == searchState.searchText.endIndex {
                searchState.searchText.replaceSubrange(range, with: filterString)
                searchState.desiredSearchSelection = nil
            } else {
                searchState.searchText.replaceSubrange(range, with: filterString)
                let index = searchState.searchText.index(range.lowerBound, offsetBy: filterString.count)
                searchState.desiredSearchSelection = .init(insertionPoint: index)
            }
            return .text
        } else {
            searchState.filters.append(filter)
            searchState.searchText = ""
            searchState.desiredSearchSelection = nil
            return .filter
        }
    }

    @discardableResult
    private func setFilterString(_ string: String) -> AddedFilterResult {
        if let range = searchState.selectedFilter.range {
            searchState.searchText.replaceSubrange(range, with: string)
            let index = searchState.searchText.index(range.lowerBound, offsetBy: string.count)
            searchState.desiredSearchSelection = .init(insertionPoint: index)
        } else {
            searchState.searchText = string
            searchState.desiredSearchSelection = nil
        }
        return .text
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

private extension CurrentlyHighlightedFilterFacade {
    var scopedRange: Range<String.Index>? {
        if let range, range != inputText.range {
            range
        } else {
            nil
        }
    }
}
