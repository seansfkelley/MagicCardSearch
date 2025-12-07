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
    @FocusState private var isSearchFocused: Bool
    
    private var hasActiveGlobalFilters: Bool {
        globalFiltersSettings.isEnabled && !globalFiltersSettings.filters.isEmpty
    }
    
    private var shouldShowAutocomplete: Bool {
        !inputText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                CardResultsView(
                    filters: $filters,
                    searchConfig: $searchConfig,
                    globalFiltersSettings: globalFiltersSettings
                )
                .opacity(shouldShowAutocomplete ? 0 : 1)
                
                if shouldShowAutocomplete {
                    AutocompleteView(inputText: inputText) { suggestion in
                        handleSuggestionTap(suggestion)
                    }
                }
            }
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                BottomBarFilterView(
                    filters: $filters,
                    inputText: $inputText,
                    isSearchFocused: _isSearchFocused,
                    onFilterSetTap: { 
                        pendingSearchConfig = searchConfig
                        showDisplaySheet = true
                    }
                )
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
    
    private func handleSuggestionTap(_ suggestion: String) {
        // Try to parse as a filter
        if let filter = SearchFilter.tryParseKeyValue(suggestion) {
            filters.append(filter)
        } else {
            // Fallback to name filter if parsing fails
            let unquoted = stripMatchingQuotes(from: suggestion)
            if !unquoted.isEmpty {
                filters.append(SearchFilter.name(unquoted))
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
