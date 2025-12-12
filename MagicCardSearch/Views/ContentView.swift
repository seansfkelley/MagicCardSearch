//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    private let historySuggestionProvider = HistorySuggestionProvider()
    @State private var filters: [SearchFilter] = []
    @State private var inputText: String = ""
    @State private var showDisplaySheet = false
    @State private var showSyntaxReference = false
    @State private var showCardList = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var autocompleteProvider: SuggestionMuxer
    @State private var inputSelection: TextSelection?
    @State private var pendingSelection: TextSelection?
    @State private var warnings: [String] = []
    @State private var showWarningsPopover = false
    @FocusState private var isSearchFocused: Bool
    
    private let searchService = CardSearchService()
    
    init() {
        _autocompleteProvider = State(initialValue: SuggestionMuxer(
            historyProvider: historySuggestionProvider,
            filterProvider: FilterTypeSuggestionProvider(),
            enumerationProvider: EnumerationSuggestionProvider()
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
                
                CardResultsView(
                    allowedToSearch: !isSearchFocused,
                    filters: $filters,
                    searchConfig: $searchConfig,
                    warnings: $warnings,
                    historySuggestionProvider: historySuggestionProvider,
                )
                .opacity(isSearchFocused ? 0 : 1)
                
                if isSearchFocused {
                    AutocompleteView(
                        inputText: inputText,
                        provider: autocompleteProvider,
                        filters: filters
                    ) { suggestion in
                            handleSuggestionTap(suggestion)
                            inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                    }
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    inputSelection: $inputSelection,
                    pendingSelection: $pendingSelection,
                    isSearchFocused: _isSearchFocused,
                    warnings: warnings,
                    showWarningsPopover: $showWarningsPopover,
                    onFilterEdit: handleFilterEdit,
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
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCardList = true
                    } label: {
                        Image(systemName: "bookmark.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: CardSearchService
                            .buildSearchURL(filters: filters, config: searchConfig, forAPI: false) ?? URL(
                                string: "https://scryfall.com"
                            )!
                    ) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(filters.isEmpty || isSearchFocused)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: filters) {
            warnings = []
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
        .sheet(isPresented: $showCardList) {
            CardListView()
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
            filters.append(filter)
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
