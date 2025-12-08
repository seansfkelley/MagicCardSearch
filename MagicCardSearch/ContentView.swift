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
    @State private var showSettingsSheet = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var globalFiltersSettings = GlobalFiltersSettings.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var historyProvider = AutocompleteProvider()
    @State private var inputSelection: TextSelection?
    @State private var pendingSelection: TextSelection?
    @FocusState private var isSearchFocused: Bool
    
    private var hasActiveGlobalFilters: Bool {
        globalFiltersSettings.isEnabled && !globalFiltersSettings.filters.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CardResultsView(
                    filters: $filters,
                    searchConfig: $searchConfig,
                    globalFiltersSettings: globalFiltersSettings
                )
                .opacity(isSearchFocused ? 0 : 1)
                
                if isSearchFocused {
                    AutocompleteView(
                        inputText: inputText,
                        suggestionProvider: historyProvider,
                        filters: filters,
                        onSuggestionTap: { suggestion in
                            handleSuggestionTap(suggestion)
                        }
                    )
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 0) {
                    if !filters.isEmpty {
                        HStack {
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
                    .badge(searchConfig.nonDefaultCount)
                }
                
                ToolbarItem(placement: .principal) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.title)
                        .foregroundStyle(.tint)
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettingsSheet = true
                    } label: {
                        Label {
                            Text("Settings")
                        } icon: {
                            Image(systemName: "gearshape.fill")
                                .font(.title2)
                        }
                    }
                    .labelStyle(.iconOnly)
                    .badge(hasActiveGlobalFilters ? " " : nil)
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
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(globalFiltersSettings: $globalFiltersSettings)
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
    
    private func handleSuggestionTap(_ suggestion: String) {
        // Try to parse as a filter
        if let filter = SearchFilter.tryParseUnambiguous(suggestion) {
            filters.append(filter)
            historyProvider.recordFilter(filter)
        } else {
            // Fallback to name filter if parsing fails
            let unquoted = stripMatchingQuotes(from: suggestion)
            if !unquoted.isEmpty {
                let filter = SearchFilter.name(unquoted)
                filters.append(filter)
                historyProvider.recordFilter(filter)
            }
        }
        
        // Clear the input text
        inputText = ""
        
        // Refocus the search field
        isSearchFocused = true
    }
    
    private func stripMatchingQuotes(from string: String) -> String {
        if string.hasPrefix("\"") && string.hasSuffix("\"") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else if string.hasPrefix("'") && string.hasSuffix("'") && string.count >= 2 {
            return String(string.dropFirst().dropLast())
        } else {
            return string
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
