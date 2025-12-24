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
    private let searchHistoryTracker = SearchHistoryTracker()
    @State private var searchFilters: [SearchFilter] = []
    @State private var inputText: String = ""
    @State private var inputSelection: TextSelection?
    @State private var searchResultsState = ScryfallSearchResultsList()
    @State private var searchTask: Task<Void, Never>?

    @State private var showDisplaySheet = false
    @State private var showBookmarkedCardList = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var mainContentType: MainContentType = .home

    @State private var isSearchSheetVisible: Bool = false

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
                    HomeView(searchHistoryTracker: searchHistoryTracker) { filters in
                        searchFilters = filters
                        startNewSearch()
                    }
                case .results:
                    SearchResultsGridView(state: searchResultsState)
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                FakeSearchBarButtonView(
                    filters: searchFilters,
                    warnings: searchResultsState.current.latestValue?.warnings ?? [],
                    onClearAll: handleClearAll,
                ) {
                    switch mainContentType {
                    case .home:
                        mainContentType = .results
                        if searchFilters.isEmpty {
                            isSearchSheetVisible = true
                        }
                    case .results:
                        isSearchSheetVisible = true
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
                                .buildSearchURL(filters: searchFilters, config: searchConfig, forAPI: false) ?? URL(
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
            startNewSearch(keepingCurrentResults: true)
        }
        .onChange(of: searchFilters) {
            // Clear warnings when filters change by resetting to unloaded or keeping existing results
            if case .loaded(let searchResults, _) = searchResultsState.current {
                searchResultsState.current = .loaded(SearchResults(
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
                searchHistoryTracker: searchHistoryTracker,
                onClearAll: handleClearAll,
            ) {
                startNewSearch()
            }
        }
    }
    
    // MARK: - Helper Methods

    private func handleClearAll() {
        searchFilters.removeAll()
        inputText = ""
        inputSelection = nil
        searchResultsState.current = .unloaded
        mainContentType = .results
        isSearchSheetVisible = true
    }

    private func startNewSearch(keepingCurrentResults: Bool = false) {
        mainContentType = .results
        
        searchTask?.cancel()
        
        logger.info("Starting new search", metadata: [
            "keepingCurrentResults": "\(keepingCurrentResults)",
            "filters": "\(searchFilters)",
            "configuration": "\(searchConfig)",
        ])
        
        guard !searchFilters.isEmpty else {
            logger.info("No search filters; skipping to empty result")
            searchResultsState.current = .unloaded
            searchTask = nil
            return
        }

        searchResultsState.current = .loading(
            // TODO: The following. The main search grid view does not blank out interaction because
            // it's being too clever.
            // keepingCurrentResults ? searchResultsState.results.latestValue : nil,
            nil,
            nil,
        )

        searchHistoryTracker.recordUsage(of: searchFilters)
        for filter in searchFilters {
            searchHistoryTracker.recordUsage(of: filter)
        }

        searchTask = Task {
            do {
                let searchResults = try await searchService.search(
                    filters: searchFilters,
                    config: searchConfig
                )
                searchResultsState.current = .loaded(searchResults, nil)
            } catch {
                if !Task.isCancelled {
                    print("Search error: \(error)")
                    searchResultsState.current = .errored(nil, SearchErrorState(from: error))
                }
            }
        }
    }
}
