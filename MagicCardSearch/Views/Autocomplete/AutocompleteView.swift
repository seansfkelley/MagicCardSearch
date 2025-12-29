//
//  AutocompleteView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import SwiftUI

struct AutocompleteView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Binding var filters: [SearchFilter]
    @Binding var suggestionLoadingState: DebouncedLoadingState
    let searchHistoryTracker: SearchHistoryTracker

    @State private var provider: CombinedSuggestionProvider
    @State private var suggestions: [Suggestion] = []
    @State private var nonce: Int = 0

    private var currentFilter: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: inputText, inputSelection: inputSelection)
    }

    init(
        inputText: Binding<String>,
        inputSelection: Binding<TextSelection?>,
        filters: Binding<[SearchFilter]>,
        suggestionLoadingState: Binding<DebouncedLoadingState>,
        searchHistoryTracker: SearchHistoryTracker
    ) {
        self._inputText = inputText
        self._inputSelection = inputSelection
        self._filters = filters
        self._suggestionLoadingState = suggestionLoadingState
        self.searchHistoryTracker = searchHistoryTracker
        
        _provider = State(initialValue: CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(),
            history: HistorySuggestionProvider(with: searchHistoryTracker),
            filterType: FilterTypeSuggestionProvider(),
            enumeration: EnumerationSuggestionProvider(),
            reverseEnumeration: ReverseEnumerationSuggestionProvider(),
            name: NameSuggestionProvider(debounce: .milliseconds(500))
        ))
    }

    private var searchSuggestionKey: SearchSuggestionKey {
        SearchSuggestionKey(inputText: inputText, filterCount: filters.count, nonce: nonce)
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
            if let filter = inputText.toSearchFilter().value {
                VerbatimRowView(
                    filter: filter,
                    onTap: addTopLevelFilter
                )
            }

            ForEach(suggestions, id: \.self) { suggestion in
                switch suggestion {
                case .pinned(let suggestion):
                    PinnedRowView(
                        suggestion: suggestion,
                        onTap: addScopedFilter
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            provider.pinnedFilterProvider.unpin(filter: suggestion.filter)
                            // If unpinning, keep the filter around in case you want to re-pin it.
                            searchHistoryTracker.recordUsage(of: suggestion.filter)
                            nonce += 1
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .tint(.orange)
                    }
                    .listRowInsets(.vertical, 0)
                case .history(let suggestion):
                    HistoryRowView(
                        suggestion: suggestion,
                        onTap: addScopedFilter
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        pinSwipeAction(for: suggestion.filter)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            searchHistoryTracker.deleteUsage(of: suggestion.filter)
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
                    EnumerationRowView(
                        suggestion: suggestion,
                        onTap: addScopedFilter
                    )
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        pinSwipeAction(for: suggestion.filter)
                    }
                    .listRowInsets(.vertical, 0)
                
                case .reverseEnumeration(let suggestion):
                    ReverseEnumerationRowView(
                        suggestion: suggestion,
                        onSelect: addScopedFilter
                    )
                    .listRowInsets(.vertical, 0)
                
                case .name(let suggestion):
                    NameRowView(
                        suggestion: suggestion,
                        onTap: addScopedFilter
                    )
                    .listRowInsets(.vertical, 0)
                }
            }
        }
        .listStyle(.plain)
        .task(id: searchSuggestionKey) {
            for await newSuggestions in provider.getSuggestions(for: currentFilter.inputText, existingFilters: Set(filters)) {
                suggestions = newSuggestions
            }
        }
    }

    private func setEntireSearch(to search: [SearchFilter]) {
        filters = search
        inputText = ""
        inputSelection = TextSelection(insertionPoint: inputText.endIndex)
        // TODO: The below, yes?
        dismiss()
    }
    
    private func addTopLevelFilter(_ filter: SearchFilter) {
        filters.append(filter)
        inputText = ""
        inputSelection = TextSelection(insertionPoint: inputText.endIndex)
    }
    
    private func addScopedFilter(_ filter: SearchFilter) {
        if let range = currentFilter.range, range != inputText.range {
            let filterString = filter.description
            inputText.replaceSubrange(range, with: filterString)
            inputSelection = TextSelection(insertionPoint: inputText.index(range.lowerBound, offsetBy: filterString.count))
        } else {
            filters.append(filter)
            inputText = ""
            inputSelection = TextSelection(insertionPoint: inputText.endIndex)
        }
    }
    
    private func setScopedString(_ string: String) {
        if let range = currentFilter.range {
            inputText.replaceSubrange(range, with: string)
            inputSelection = TextSelection(insertionPoint: inputText.index(range.lowerBound, offsetBy: string.count))
        } else {
            inputText = string
            inputSelection = TextSelection(insertionPoint: inputText.endIndex)
        }
    }

    @ViewBuilder
    private func pinSwipeAction(for filter: SearchFilter) -> some View {
        Button {
            provider.pinnedFilterProvider.pin(filter: filter)
            nonce += 1
        } label: {
            Label("Pin", systemImage: "pin")
        }
        .tint(.orange)
    }
}
