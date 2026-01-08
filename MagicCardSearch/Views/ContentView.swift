import SwiftUI
import OSLog
import ScryfallKit

private let logger = Logger(subsystem: "MagicCardSearch", category: "ContentView")

enum MainContentType {
    case home
    case results
}

struct ContentView: View {
    @Binding var searchState: SearchState

    @State private var showDisplaySheet = false
    @State private var showBookmarkedCardList = false
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var mainContentType: MainContentType = .home

    @State private var showSearchSheet: Bool = false

    private let searchService = CardSearchService()

    var body: some View {
        NavigationStack {
            ZStack {
                // Apparently required to get the floating search bar to respond to light/dark
                // correctly; I guess it was pulling its base color from the default non-responsive
                // (?) background color.
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()
                
                switch mainContentType {
                case .home:
                    HomeView(searchState: $searchState)
                case .results:
                    SearchResultsGridView(list: searchState.results ?? .empty(), searchState: $searchState)
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                FakeSearchBarButtonView(
                    filters: searchState.filters,
                    warnings: searchState.results?.value.latestValue?.warnings ?? [],
                    onClearAll: searchState.clearAll,
                ) {
                    showSearchSheet = true
                    // Awkward, but seems to be the best way to match only one case in
                    // the absence of conformance to Equatable, which is sort of intentional.
                    let unloaded = if case .unloaded = searchState.results?.value { true } else { false }

                    if !unloaded && !searchState.filters.isEmpty {
                        mainContentType = .results
                    }
                }
            }
            .toolbar {
                if mainContentType == .results {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            pendingSearchConfig = searchState.configuration
                            showDisplaySheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button {
                        mainContentType = .home
                        showSearchSheet = false
                    } label: {
                        Image("HeaderIcon")
                            .resizable()
                            .scaledToFit()
                            // TODO: Figure out how to do this without fixed numbers. Toolbar should
                            // set the size of the icon.
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.glass)
                    .buttonBorderShape(.circle)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBookmarkedCardList = true
                    } label: {
                        Image(systemName: "bookmark.circle")
                    }
                }

                if mainContentType == .results {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: CardSearchService
                                .buildSearchURL(filters: searchState.filters, config: searchState.configuration, forAPI: false) ?? URL(
                                    string: "https://scryfall.com"
                                )!
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: searchState.searchNonce) {
            mainContentType = .results
            showDisplaySheet = false
            showBookmarkedCardList = false
            showSearchSheet = false
        }
        .onChange(of: searchState.clearNonce) {
            mainContentType = .home
            showDisplaySheet = false
            showBookmarkedCardList = false
            showSearchSheet = true
        }
        .onChange(of: searchState.filters) { _, newFilters in
            searchState.results?.clearWarnings()
            if newFilters.isEmpty {
                mainContentType = .home
            }
        }
        .sheet(isPresented: $showDisplaySheet, onDismiss: {
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
        .sheet(isPresented: $showBookmarkedCardList) {
            BookmarkedCardsListView(searchState: $searchState)
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheetView(searchState: $searchState)
        }
    }
}
