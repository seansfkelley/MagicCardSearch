import SwiftUI

struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    @Binding var searchState: SearchState

    @State private var suggestionLoadingState = DebouncedLoadingState()
    @State private var showSyntaxReference = false

    var body: some View {
        NavigationStack {
            AutocompleteView(
                searchState: $searchState,
                suggestionLoadingState: $suggestionLoadingState,
            )
            .onChange(of: searchState.searchNonce) {
                dismiss()
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
                        searchState.performSearch()
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
                )
            }
            .sheet(isPresented: $showSyntaxReference) {
                SyntaxReferenceView()
            }
        }
    }
}
