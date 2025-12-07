//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var filters: [SearchFilter] = []
    @State private var showDisplaySheet = false
    @State private var showSettingsSheet = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var globalFiltersSettings = GlobalFiltersSettings.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var unparsedInputText: String = ""
    @FocusState private var isSearchFocused: Bool
    
    private var hasActiveGlobalFilters: Bool {
        globalFiltersSettings.isEnabled && !globalFiltersSettings.filters.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            CardResultsView(
                filters: $filters,
                searchConfig: $searchConfig,
                globalFiltersSettings: globalFiltersSettings
            )
            .contentShape(Rectangle())
            .safeAreaInset(edge: .bottom) {
                SearchBarContainerView(
                    filters: $filters,
                    unparsedInputText: $unparsedInputText,
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
}

// MARK: - Preview

#Preview {
    ContentView()
}
