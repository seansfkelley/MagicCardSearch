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
                        item: CardSearchService
                            .buildSearchURL(
                                filters: searchState.filters,
                                config: searchState.configuration,
                                forAPI: false
                            ) ?? URL(string: "https://scryfall.com")!
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: showSearchSheet) { _, isShowing in
            if isShowing {
                editingState = searchState.makeEditingState()
            }
        }
        .sheet(isPresented: $showSearchSheet, onDismiss: { editingState = nil }) {
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
        .sheet(isPresented: $showDisplayOptionsSheet, onDismiss: {
            if let pending = pendingSearchConfig, pending != searchState.configuration {
                searchState.search(withConfiguration: pending)
            }
            pendingSearchConfig = nil
        }) {
            NavigationStack {
                DisplayOptionsView(searchConfig: Binding(
                    get: { pendingSearchConfig ?? searchState.configuration },
                    set: { pendingSearchConfig = $0 }
                ))
            }
            .presentationDetents([.medium])
        }
    }
}
