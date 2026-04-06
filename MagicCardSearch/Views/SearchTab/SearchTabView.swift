import SwiftUI
import ScryfallKit
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchTabView")

struct SearchTabView: View {
    @Binding var searchState: SearchState
    @Binding var showSearchSheet: Bool

    @State private var showDisplayOptionsSheet = false
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var editingState: SearchEditingState?

    var body: some View {
        Group {
            if let results = searchState.results {
                SearchResultsGridView(list: results, searchState: $searchState)
            } else {
                SearchLandingView(searchState: $searchState)
            }
        }
        .safeAreaInset(edge: .bottom) {
            FakeSearchBarButtonView(searchState: $searchState) {
                showSearchSheet = true
            }
            .padding(.bottom)
            .padding(.horizontal, SearchTabConstants.horizontalPadding)
        }
        .toolbar {
            if searchState.results != nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        pendingSearchConfig = searchState.configuration
                        showDisplayOptionsSheet = true
                    } label: {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: scryfallSearchUrl(
                            forFilters: searchState.filters,
                            config: searchState.configuration
                        ) ?? URL(string: "https://scryfall.com")!
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showSearchSheet) {
            // A bit unfortunate to have derived state like this, but it's simple to enforce and
            // simple to understand and allows parent views to programmatically open the search.
            if showSearchSheet {
                editingState = searchState.makeEditingState()
            } else {
                editingState = nil
            }
        }
        .sheet(isPresented: $showSearchSheet) {
            if let editingState {
                NavigationStack {
                    SearchSheetView(
                        editingState: editingState,
                        // TODO: Should we display the warnings here?
                        warnings: searchState.results?.value.latestValue?.warnings ?? [],
                    ) {
                        // n.b. we throw out any incomplete state in the search bar by design.
                        searchState.search(withFilters: editingState.filters)
                        showSearchSheet = false
                    }
                }
            }
        }
        .sheet(isPresented: $showDisplayOptionsSheet) {
            NavigationStack {
                SearchConfigurationView(initialSearchConfig: searchState.configuration) {
                    searchState.search(withConfiguration: $0)
                }
            }
            .presentationDetents([.medium])
        }
    }
}

private struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let editingState: SearchEditingState
    let warnings: [String]
    let onSearch: () -> Void

    @State private var showSyntaxReference = false

    var body: some View {
        AutocompleteView(editingState: editingState, onSearch: onSearch)
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(editingState: editingState, warnings: warnings, onSearch: onSearch)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Image(systemName: "book")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showSyntaxReference) {
                NavigationStack {
                    SyntaxReferenceView()
                }
            }
    }
}
