import SwiftUI

struct AutocompleteView: View {
    @ScaledMetric private var iconWidth = AutocompleteConstants.defaultSuggestionIconWidth
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    var editingState: SearchEditingState
    let onSearch: () -> Void

    @State private var suggestions: [AutocompleteSuggestion] = []
    @State private var nonce: Int = 0

    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(
            inputText: editingState.searchText,
            filterCount: editingState.filters.count,
            currentFilterRange: editingState.selectedFilter.range,
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
            if let filter = PartialFilterQuery.from(editingState.searchText, autoclosePairedDelimiters: true).value?.transformLeaves(using: FilterTerm.from) {
                Button {
                    editingState.filters.append(filter)
                    editingState.searchText = ""
                    editingState.desiredSearchSelection = nil
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

            // The hash value is stable enough that the swipe-delete animations don't get horribly
            // mangled. If you have a hash collision on the few-dozen items that exist in the list
            // at any given time... I'm impressed.
            //
            // Note that the animations still look kinda weird because the new suggestions typically
            // come in way before it's done so it jerks to an instantaneous completion partway
            // through. Before this the implementation used to key by index, which caused all kinds
            // of nonsense when the list got reordered. Another try I did had sync
            // (i.e. faster-than-autocomplete) state tracking what was deleted and not rendering it,
            // but that just guaranteed that the animation would be instantaneous.
            ForEach(suggestions, id: \.hashValue) { suggestion in
                suggestionRow(suggestion)
                    .listRowInsets(.vertical, 0)
            }
        }
        .listStyle(.plain)
        .scrollDismissesKeyboard(.interactively)
        .task(id: searchSuggestionKey) {
            guard let newSuggestions = try? await editingState.getSuggestions() else { return }
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
        let shouldSearchImmediately = suggestion.source == .name && editingState.selectedFilter.scopedRange == nil

        let row = FilterRowView(
            suggestion: suggestion,
            showImmediateSearchIcon: shouldSearchImmediately,
        ) { filter in
            // Belt-and-suspenders to make sure we don't search immediately if we somehow only ended
            // up modifying the search text.
            if addFilter(filter) == .filter && shouldSearchImmediately {
                onSearch()
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
        if let range = editingState.selectedFilter.scopedRange {
            let filterString = filter.description
            if range.upperBound == editingState.searchText.endIndex {
                editingState.searchText.replaceSubrange(range, with: filterString)
                editingState.desiredSearchSelection = nil
            } else {
                editingState.searchText.replaceSubrange(range, with: filterString)
                let index = editingState.searchText.index(range.lowerBound, offsetBy: filterString.count)
                editingState.desiredSearchSelection = .init(insertionPoint: index)
            }
            return .text
        } else {
            editingState.filters.append(filter)
            editingState.searchText = ""
            editingState.desiredSearchSelection = nil
            return .filter
        }
    }

    @discardableResult
    private func setFilterString(_ string: String) -> AddedFilterResult {
        if let range = editingState.selectedFilter.range {
            editingState.searchText.replaceSubrange(range, with: string)
            let index = editingState.searchText.index(range.lowerBound, offsetBy: string.count)
            editingState.desiredSearchSelection = .init(insertionPoint: index)
        } else {
            editingState.searchText = string
            editingState.desiredSearchSelection = nil
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
