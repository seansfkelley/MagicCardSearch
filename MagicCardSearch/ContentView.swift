//
//  ContentView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-03.
//

import SwiftUI

struct ContentView: View {
    @State private var filters: [SearchFilter] = []
    @State private var showTopBar = true
    @State private var showDisplaySheet = false
    @State private var showSettingsSheet = false
    @State private var searchConfig = SearchConfiguration.load()
    @State private var globalFiltersSettings = GlobalFiltersSettings.load()
    @State private var pendingSearchConfig: SearchConfiguration?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            CardResultsView(
                filters: $filters,
                searchConfig: $searchConfig,
                globalFiltersSettings: globalFiltersSettings
            )
            .simultaneousGesture(
                TapGesture()
                    .onEnded { _ in
                        isSearchFocused = false
                    }
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        isSearchFocused = false
                    }
            )
            
            if showTopBar {
                TopBarView(
                    onDisplayTap: { 
                        pendingSearchConfig = searchConfig
                        showDisplaySheet = true
                    },
                    onSettingsTap: { showSettingsSheet = true },
                    badgeCount: searchConfig.nonDefaultCount
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            SearchBarView(
                filters: $filters,
                isSearchFocused: _isSearchFocused,
                onFilterSetTap: { 
                    pendingSearchConfig = searchConfig
                    showDisplaySheet = true
                }
            )
        }
        .animation(.easeInOut(duration: 0.25), value: showTopBar)
        .sheet(isPresented: $showDisplaySheet, onDismiss: {
            if let pending = pendingSearchConfig, pending != searchConfig {
                searchConfig = pending
                searchConfig.save() // Persist changes
            }
            pendingSearchConfig = nil
        }) {
            DisplaySortSheetView(searchConfig: Binding(
                get: { pendingSearchConfig ?? searchConfig },
                set: { pendingSearchConfig = $0 }
            ))
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView(globalFiltersSettings: $globalFiltersSettings)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
