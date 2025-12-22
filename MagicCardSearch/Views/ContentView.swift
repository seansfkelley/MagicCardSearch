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
    @State private var showDisplaySheet = false
    @State private var showSyntaxReference = false
    @State private var showBookmarkedCardList = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var autocompleteProvider: CombinedSuggestionProvider
    @State private var inputSelection: TextSelection?
    @State private var pendingSelection: TextSelection?
    @State private var searchResultsState = ScryfallSearchResultsList()
    @State private var showWarningsPopover = false
    @State private var searchTask: Task<Void, Never>?
    @State private var mainContentType: MainContentType = .home
    @FocusState private var isSearchFocused: Bool
    
    private let searchService = CardSearchService()
    
    private var filterFacade: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: $inputText, inputSelection: $inputSelection)
    }
    
    init() {
        _autocompleteProvider = State(initialValue: CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(),
            history: HistorySuggestionProvider(with: searchHistoryTracker),
            filterType: FilterTypeSuggestionProvider(),
            enumeration: EnumerationSuggestionProvider(),
            name: NameSuggestionProvider(debounce: .milliseconds(500))
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
                    HomeView(searchHistoryTracker: searchHistoryTracker) { filters in
                        searchFilters = filters
                        startNewSearch()
                    }
                case .results:
                    if isSearchFocused {
                        AutocompleteView(
                            filterText: filterFacade.currentFilter,
                            provider: autocompleteProvider,
                            searchHistoryTracker: searchHistoryTracker,
                            filters: searchFilters,
                            isSearchFocused: isSearchFocused,
                            onSuggestionTap: handleSuggestionTap,
                        )
                    } else {
                        SearchResultsGridView(state: searchResultsState)
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
                    warnings: searchResultsState.current.latestValue?.warnings ?? [],
                    showWarningsPopover: $showWarningsPopover,
                    onFilterEdit: handleFilterEdit,
                    searchHistoryTracker: searchHistoryTracker,
                    onSubmit: { startNewSearch() },
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
                        isSearchFocused = false
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
        .onChange(of: searchConfig) {
            startNewSearch(keepingCurrentResults: true)
        }
        .onChange(of: isSearchFocused) { _, isFocused in
            if isFocused {
                mainContentType = .results
            }
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
    
    private func handleFilterEdit(_ filter: SearchFilter) {
        inputText = filter.description
        let selection = TextSelection(range: filter.suggestedEditingRange)
        
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
            inputText.replaceSubrange(filterFacade.currentFilterRange, with: string)
        }
        inputSelection = TextSelection(insertionPoint: inputText.endIndex)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
