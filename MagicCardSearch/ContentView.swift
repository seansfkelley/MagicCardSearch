//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var filters: [SearchFilter] = []
    @State private var inputText: String = ""
    @State private var showDisplaySheet = false
    @State private var showSyntaxReference = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var historyProvider = AutocompleteProvider()
    @State private var inputSelection: TextSelection?
    @State private var pendingSelection: TextSelection?
    @State private var warnings: [String] = []
    @State private var showWarningsPopover = false
    @FocusState private var isSearchFocused: Bool
    
    private let searchService = CardSearchService()
    
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
                    warnings: $warnings
                )
                .opacity(isSearchFocused ? 0 : 1)
                
                if isSearchFocused {
                    AutocompleteView(
                        inputText: inputText,
                        suggestionProvider: historyProvider,
                        filters: filters,
                        onSuggestionTap: { suggestion in
                            handleSuggestionTap(suggestion)
                            inputSelection = TextSelection(insertionPoint: inputText.endIndex)
                        }
                    )
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if !filters.isEmpty {
                        HStack {
                            // Warnings button
                            if !warnings.isEmpty {
                                Button {
                                    showWarningsPopover.toggle()
                                } label: {
                                    Text(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .padding(.horizontal)
                                        .padding(.vertical, 6)
                                }
                                .foregroundStyle(.orange)
                                .glassEffect(.regular.interactive())
                                .popover(isPresented: $showWarningsPopover) {
                                    VStack(alignment: .leading, spacing: 0) {
                                        ForEach(Array(warnings.enumerated()), id: \.offset) { index, warning in
                                            Text(warning)
                                                .font(.subheadline)
                                                .padding()
                                            
                                            if index < warnings.count - 1 {
                                                Divider()
                                                    .padding(.horizontal)
                                            }
                                        }
                                    }
                                    .frame(maxWidth: 300)
                                    .presentationCompactAdaptation(.popover)
                                }
                            }
                            
                            Spacer()
                            
                            Button(role: .destructive, action: {
                                filters.removeAll()
                            }) {
                                Text("Clear all")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal)
                                    .padding(.vertical, 6)
                            }
                            .glassEffect(.regular.interactive())
                        }
                        .padding(.horizontal)
                    }
                    
                    BottomBarFilterView(
                        filters: $filters,
                        inputText: $inputText,
                        inputSelection: $inputSelection,
                        pendingSelection: $pendingSelection,
                        isSearchFocused: _isSearchFocused,
                        historyProvider: historyProvider,
                        onFilterEdit: handleFilterEdit
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ControlGroup {
                        Button {
                            pendingSearchConfig = searchConfig
                            showDisplaySheet = true
                        } label: {
                            Label {
                                Text("Sort & Display")
                            } icon: {
                                Image(systemName: "arrow.up.arrow.down")
                                    .font(.title2)
                            }
                        }
                        .labelStyle(.iconOnly)
                        
                        Button {
                            showSyntaxReference = true
                        } label: {
                            Label {
                                Text("Syntax Reference")
                            } icon: {
                                Image(systemName: "book")
                                    .font(.title2)
                            }
                        }
                        .labelStyle(.iconOnly)
                    }
                }
                
                ToolbarItem(placement: .principal) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(
                        item: CardSearchService
                            .buildSearchURL(filters: filters, config: searchConfig, forAPI: false) ?? URL(
                                string: "https://scryfall.com"
                            )!
                    ) {
                        Label {
                            Text("Share Search")
                        } icon: {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .disabled(filters.isEmpty)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
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
            historyProvider.recordFilterUsage(filter)
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
