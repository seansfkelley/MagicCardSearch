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
    @State private var suggestionLoadingState = DebouncedLoadingState()
    @State private var showSyntaxReference = false

    var body: some View {
        NavigationStack {
            AutocompleteView(
                inputText: $inputText,
                inputSelection: $inputSelection,
                filters: $filters,
                suggestionLoadingState: $suggestionLoadingState,
                searchHistoryTracker: searchHistoryTracker,
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
                    isAutocompleteLoading: suggestionLoadingState.isLoadingDebounced,
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
}
