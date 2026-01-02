//
//  SearchSheetView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-24.
//
import SwiftUI

struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var searchState: SearchState
    let onClearAll: () -> Void
    let onSubmit: () -> Void

    @State private var suggestionLoadingState = DebouncedLoadingState()
    @State private var showSyntaxReference = false

    var body: some View {
        NavigationStack {
            AutocompleteView(
                searchState: $searchState,
                suggestionLoadingState: $suggestionLoadingState,
            ) {
                dismiss()
                onSubmit()
            }
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
                    searchState: $searchState,
                    isAutocompleteLoading: suggestionLoadingState.isLoadingDebounced,
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
        searchState.searchText = filter.description
        searchState.searchSelection = TextSelection(range: filter.suggestedEditingRange)
    }
}
