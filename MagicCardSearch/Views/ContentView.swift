//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//
import SwiftUI
import Logging

private let logger = Logger(label: "ContentView")

enum MainContentType {
    case home
    case results
}

struct ContentView: View {
    private let searchState: SearchState
    private let historyAndPinnedState: HistoryAndPinnedState

    @State private var showDisplaySheet = false
    @State private var showBookmarkedCardList = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var mainContentType: MainContentType = .home

    @State private var isSearchSheetVisible: Bool = false

    private let searchService = CardSearchService()

    init() {
        // TODO: This try!... what do we do if we fail?
        let db = try! SQLiteDatabase.initialize(.filename("MagicCardSearch.db"))
        searchState = SearchState(
            filterHistory: db.filterHistory,
            searchHistory: db.searchHistory,
            pinnedFilter: db.pinnedFilters
        )
        historyAndPinnedState = HistoryAndPinnedState(
            filterHistory: db.filterHistory,
            searchHistory: db.searchHistory,
            pinnedFilter: db.pinnedFilters,
        )
    }

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
                    HomeView(historyAndPinnedState: historyAndPinnedState,
                    ) { filters in
                        searchState.filters = filters
                        startNewSearch()
                    }
                case .results:
                    SearchResultsGridView(list: searchState.results ?? .empty())
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                FakeSearchBarButtonView(
                    filters: searchState.filters,
                    warnings: searchState.results.value.latestValue?.warnings ?? [],
                    onClearAll: handleClearAll,
                ) {
                    isSearchSheetVisible = true
                    // Awkward, but seems to be the best way to negatively match only one case?
                    guard case .unloaded = searchState.results.value else {
                        mainContentType = .results
                        return
                    }
                }
            }
            .toolbar {
                if mainContentType == .results {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            pendingSearchConfig = searchConfig
                            showDisplaySheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button {
                        mainContentType = .home
                        isSearchSheetVisible = false
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
                                .buildSearchURL(filters: searchState.filters, config: searchConfig, forAPI: false) ?? URL(
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
        .onChange(of: searchConfig) {
            startNewSearch()
        }
        .onChange(of: searchState.filters) {
            // Clear warnings when filters change by resetting to unloaded or keeping existing results
            if case .loaded(let results, _) = searchResultsState.current {
                searchState.value = .loaded(SearchResults(
                    cards: searchResults.cards,
                    totalCount: searchResults.totalCount,
                    nextPageUrl: searchResults.nextPageUrl,
                    warnings: [],
                ), nil)
            }
        }
        .sheet(isPresented: $showDisplaySheet, onDismiss: {
            if let pending = pendingSearchConfig, pending != searchConfig {
                searchConfig = pending
                searchConfig.save()
            }
            pendingSearchConfig = nil
        }) {
            DisplayOptionsView(searchConfig: Binding(
                get: { pendingSearchConfig ?? searchConfig },
                set: { pendingSearchConfig = $0 }
            ))
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showBookmarkedCardList) {
            BookmarkedCardsListView()
        }
        .sheet(isPresented: $isSearchSheetVisible) {
            SearchSheetView(
                inputText: $inputText,
                inputSelection: $inputSelection,
                filters: $searchFilters,
                warnings: searchResultsState.current.latestValue?.warnings ?? [],
                searchState: searchState,
                historyAndPinnedState: historyAndPinnedState,
                onClearAll: handleClearAll,
            ) {
                startNewSearch()
            }
        }
    }
    
    // MARK: - Helper Methods

    private func handleClearAll() {
        searchState.clearAll()
        isSearchSheetVisible = true
        // Don't change the main view until the search begins!
    }

    private func startNewSearch() {
        mainContentType = .results
        searchState.performSearch(withConfiguration: searchConfig)
    }
}
