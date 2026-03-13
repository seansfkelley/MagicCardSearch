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

    var body: some View {
        NavigationStack {
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
        }
        .onChange(of: searchState.filters) { _, newFilters in
            searchState.results?.clearWarnings()
            if newFilters.isEmpty {
                searchState.results = nil
            }
        }
        .onChange(of: searchState.searchNonce) {
            showSearchSheet = false
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheetView(searchState: $searchState)
        }
        .sheet(isPresented: $showDisplayOptionsSheet, onDismiss: {
            if let pending = pendingSearchConfig, pending != searchState.configuration {
                searchState.configuration = pending
                searchState.performSearch()
                searchState.configuration.save()
            }
            pendingSearchConfig = nil
        }) {
            DisplayOptionsView(searchConfig: Binding(
                get: { pendingSearchConfig ?? searchState.configuration },
                set: { pendingSearchConfig = $0 }
            ))
            .presentationDetents([.medium])
        }
    }
}
