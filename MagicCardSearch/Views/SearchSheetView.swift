//
//  SearchSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-24.
//
import SwiftUI

struct SearchSheetView: View {
    @Binding var inputText: String
    @Binding var inputSelection: TextSelection?
    @Binding var filters: [SearchFilter]
    let warnings: [String]
    let searchHistoryTracker: SearchHistoryTracker

    let onClearAll: () -> Void
    let onSubmit: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var provider: CombinedSuggestionProvider
    @State private var showSyntaxReference = false

    init(
        inputText: Binding<String>,
        inputSelection: Binding<TextSelection?>,
        filters: Binding<[SearchFilter]>,
        warnings: [String],
        searchHistoryTracker: SearchHistoryTracker,
        onClearAll: @escaping () -> Void,
        onSubmit: @escaping () -> Void
    ) {
        _inputText = inputText
        _inputSelection = inputSelection
        _filters = filters
        self.warnings = warnings
        self.searchHistoryTracker = searchHistoryTracker
        self.onClearAll = onClearAll
        self.onSubmit = onSubmit

        // This is why we have to have a custom initializer. :/
        _provider = State(initialValue: CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(),
            history: HistorySuggestionProvider(with: searchHistoryTracker),
            filterType: FilterTypeSuggestionProvider(),
            enumeration: EnumerationSuggestionProvider(),
            reverseEnumeration: ReverseEnumerationSuggestionProvider(),
            name: NameSuggestionProvider(debounce: .milliseconds(500))
        ))
    }

    private var filterFacade: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: inputText, inputSelection: inputSelection)
    }

    var body: some View {
        NavigationStack {
            AutocompleteView(
                allText: inputText,
                filterText: filterFacade.currentFilter,
                provider: provider,
                searchHistoryTracker: searchHistoryTracker,
                filters: filters,
                onSuggestionTap: handleSuggestionTap,
            )
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Image(systemName: "book")
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                        onSubmit()
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(
                    filters: $filters,
                    warnings: warnings,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    autocompleteProvider: provider,
                    searchHistoryTracker: searchHistoryTracker,
                    onFilterEdit: handleFilterEdit,
                    onClearAll: onClearAll,
                ) {
                    dismiss()
                    onSubmit()
                }
            }
            .sheet(isPresented: $showSyntaxReference) {
                SyntaxReferenceView()
            }
        }
    }

    private func handleFilterEdit(_ filter: SearchFilter) {
        inputText = filter.description
        inputSelection = TextSelection(range: filter.suggestedEditingRange)
    }

    private func handleSuggestionTap(_ suggestion: AutocompleteView.AcceptedSuggestion) {
        switch suggestion {
        case .filter(let filter):
            if let range = filterFacade.currentFilterRange, range != inputText.range {
                let filterString = filter.description
                inputText.replaceSubrange(range, with: filterString)
                inputSelection = TextSelection(insertionPoint: inputText.index(range.lowerBound, offsetBy: filterString.count))
            } else {
                filters.append(filter)
                inputText = ""
                inputSelection = TextSelection(insertionPoint: inputText.endIndex)
            }
        case .string(let string):
            if let range = filterFacade.currentFilterRange {
                inputText.replaceSubrange(range, with: string)
                inputSelection = TextSelection(insertionPoint: inputText.index(range.lowerBound, offsetBy: string.count))
            } else {
                inputText = string
                inputSelection = TextSelection(insertionPoint: inputText.endIndex)
            }
        }
    }
}
