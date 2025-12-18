//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

enum MainContentType {
    case home
    case results
}

struct ContentView: View {
    private let historySuggestionProvider = HistorySuggestionProvider()
    @State private var searchFilters: [SearchFilter] = []
    @State private var inputText: String = ""
    @State private var showDisplaySheet = false
    @State private var showSyntaxReference = false
    @State private var showBookmarkedCardList = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var autocompleteProvider: CombinedSuggestionProvider
    @State private var inputSelection: TextSelection?
    @State private var pendingSelection: TextSelection?
    @State private var results: LoadableResult<SearchResults, SearchErrorState> = .unloaded
    @State private var showWarningsPopover = false
    @State private var searchTask: Task<Void, Never>?
    @State private var mainContentType: MainContentType = .home
    @FocusState private var isSearchFocused: Bool
    
    private let searchService = CardSearchService()
    
    init() {
        _autocompleteProvider = State(initialValue: CombinedSuggestionProvider(
            historyProvider: historySuggestionProvider,
            filterProvider: FilterTypeSuggestionProvider(),
            enumerationProvider: EnumerationSuggestionProvider(),
            nameProvider: NameSuggestionProvider(debounce: .milliseconds(500))
        ))
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
                    ContentUnavailableView(
                        "Home!",
                        systemImage: "magnifyingglass",
                    )
                case .results:
                    SearchResultsGridView(
                        results: $results,
                        onLoadNextPage: loadNextPageIfNeeded,
                        onRetryNextPage: retryNextPage
                    )
                }
                
                if isSearchFocused {
                    AutocompleteView(
                        inputText: inputText,
                        provider: autocompleteProvider,
                        filters: searchFilters,
                        isSearchFocused: isSearchFocused
                    ) { suggestion in
                            handleSuggestionTap(suggestion)
                            inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                    }
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                BottomBarFilterView(
                    filters: $searchFilters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    pendingSelection: $pendingSelection,
                    isSearchFocused: _isSearchFocused,
                    warnings: results.latestValue?.warnings ?? [],
                    showWarningsPopover: $showWarningsPopover,
                    onFilterEdit: handleFilterEdit,
                    historySuggestionProvider: historySuggestionProvider,
                    onSubmit: performSearch,
                    autocompleteProvider: autocompleteProvider
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ControlGroup {
                        Button {
                            pendingSearchConfig = searchConfig
                            showDisplaySheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        Button {
                            showSyntaxReference = true
                        } label: {
                            Image(systemName: "book")
                        }
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Button {
                        mainContentType = .home
                    } label: {
                        Image("HeaderIcon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 32)
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showBookmarkedCardList = true
                    } label: {
                        Image(systemName: "bookmark.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: CardSearchService
                            .buildSearchURL(filters: searchFilters, config: searchConfig, forAPI: false) ?? URL(
                                string: "https://scryfall.com"
                            )!
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(searchFilters.isEmpty || isSearchFocused)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: searchFilters) {
            // Clear warnings when filters change by resetting to unloaded or keeping existing results
            if case .loaded(let searchResults, _) = results {
                results = .loaded(SearchResults(
                    totalCount: searchResults.totalCount,
                    cards: searchResults.cards,
                    warnings: [],
                    nextPageUrl: searchResults.nextPageUrl
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
        .sheet(isPresented: $showSyntaxReference) {
            SyntaxReferenceView()
        }
        .sheet(isPresented: $showBookmarkedCardList) {
            BookmarkedCardsListView()
        }
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showWarningsPopover = false
                    }
                }
        )
        .simultaneousGesture(
            DragGesture(minimumDistance: 1)
                .onChanged { _ in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        showWarningsPopover = false
                    }
                }
        )
    }
    
    // MARK: - Helper Methods
    
    private func performSearch() {
        mainContentType = .results
        
        searchTask?.cancel()

        guard !searchFilters.isEmpty else {
            results = .unloaded
            searchTask = nil
            return
        }

        print("Searching...")

        results = .loading(results.latestValue, nil)

        for filter in searchFilters {
            historySuggestionProvider.recordUsage(of: filter)
        }

        searchTask = Task {
            do {
                let searchResult = try await searchService.search(
                    filters: searchFilters,
                    config: searchConfig
                )
                let searchResults = SearchResults(
                    totalCount: searchResult.totalCount,
                    cards: searchResult.cards,
                    warnings: searchResult.warnings,
                    nextPageUrl: searchResult.nextPageURL,
                )
                results = .loaded(searchResults, nil)
            } catch {
                if !Task.isCancelled {
                    print("Search error: \(error)")
                    results = .errored(results.latestValue, SearchErrorState(from: error))
                }
            }
        }
    }
    
    private func loadNextPageIfNeeded() {
        guard case .loaded(let searchResults, _) = results,
              let nextUrl = searchResults.nextPageUrl else {
            return
        }

        print("Loading next page \(nextUrl)")

        results = .loading(searchResults, nil)

        Task {
            do {
                let searchResult = try await searchService.fetchNextPage(from: nextUrl)
                let updatedResults = SearchResults(
                    totalCount: searchResults.totalCount,
                    cards: searchResults.cards + searchResult.cards,
                    warnings: searchResults.warnings,
                    nextPageUrl: searchResult.nextPageURL,
                )
                results = .loaded(updatedResults, nil)
            } catch {
                print("Error loading next page: \(error)")
                results = .errored(searchResults, SearchErrorState(from: error))
            }
        }
    }

    private func retryNextPage() {
        // Clear the error and retry
        if case .errored(let value, _) = results, let searchResults = value {
            results = .loaded(searchResults, nil)
            loadNextPageIfNeeded()
        }
    }
    
    private func handleFilterEdit(_ filter: SearchFilter) {
        let (filterString, range) = filter.queryStringWithEditingRange
        inputText = filterString
        let selection = TextSelection(range: range)
        
        // Unfortunate, but seems to be the only way that we can reliably focus the
        // text whether or not the text field is currently focused.
        if isSearchFocused {
            inputSelection = selection
        } else {
            pendingSelection = selection
            isSearchFocused = true
        }
    }
    
    private func handleSuggestionTap(_ suggestion: AutocompleteView.AcceptedSuggestion) {
        switch suggestion {
        case .filter(let filter):
            searchFilters.append(filter)
            inputText = ""
            
        case .string(let string):
            inputText = string
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
