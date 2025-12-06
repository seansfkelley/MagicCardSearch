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
    @State private var pendingSearchConfig: SearchConfiguration?
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            CardResultsView(filters: $filters, searchConfig: $searchConfig)
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
            SettingsSheetView()
        }
    }
}

// MARK: - Search Configuration

struct SearchConfiguration: Equatable {
    var displayMode: DisplayMode = .cards
    var sortField: SortField = .name
    var sortOrder: SortOrder = .auto
    
    // Default configuration for comparison
    static let defaultConfig = SearchConfiguration()
    
    // Count how many settings differ from default
    var nonDefaultCount: Int {
        var count = 0
        if displayMode != SearchConfiguration.defaultConfig.displayMode { count += 1 }
        if sortField != SearchConfiguration.defaultConfig.sortField { count += 1 }
        if sortOrder != SearchConfiguration.defaultConfig.sortOrder { count += 1 }
        return count
    }
    
    // Reset to defaults
    mutating func resetToDefaults() {
        displayMode = .cards
        sortField = .name
        sortOrder = .auto
    }
    
    enum DisplayMode: String, CaseIterable, Codable {
        case cards = "Cards"
        case allPrints = "All Prints"
        case uniqueArt = "Unique Art"
        
        var apiValue: String {
            switch self {
            case .cards: return "cards"
            case .allPrints: return "prints"
            case .uniqueArt: return "art"
            }
        }
    }
    
    enum SortField: String, CaseIterable, Codable {
        case name = "Name"
        case power = "Power"
        case toughness = "Toughness"
        
        var apiValue: String {
            switch self {
            case .name: return "name"
            case .power: return "power"
            case .toughness: return "toughness"
            }
        }
        
        // Constant mapping for extensibility
        static let apiFieldNames: [SortField: String] = [
            .name: "name",
            .power: "power",
            .toughness: "toughness"
        ]
    }
    
    enum SortOrder: String, CaseIterable, Codable {
        case auto = "Auto"
        case ascending = "Ascending"
        case descending = "Descending"
        
        var apiValue: String {
            switch self {
            case .auto: return "auto"
            case .ascending: return "asc"
            case .descending: return "desc"
            }
        }
    }
}

// MARK: - Search Configuration Persistence

extension SearchConfiguration: Codable {
    private enum CodingKeys: String, CodingKey {
        case displayMode, sortField, sortOrder
    }
    
    // Save to UserDefaults
    func save() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: "searchConfiguration")
        }
    }
    
    // Load from UserDefaults
    static func load() -> SearchConfiguration {
        guard let data = UserDefaults.standard.data(forKey: "searchConfiguration"),
              let config = try? JSONDecoder().decode(SearchConfiguration.self, from: data) else {
            return SearchConfiguration() // Return default if not found
        }
        return config
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    let onDisplayTap: () -> Void
    let onSettingsTap: () -> Void
    let badgeCount: Int
    
    var body: some View {
        HStack {
            Button(action: onDisplayTap) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.title2)
                        .foregroundStyle(.primary)
                        .frame(width: 44, height: 44)
                    
                    if badgeCount > 0 {
                        Text("\(badgeCount)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Circle().fill(.red))
                            .offset(x: 8, y: 4)
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.title)
                .foregroundStyle(.tint)
            
            Spacer()
            
            Button(action: onSettingsTap) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

// MARK: - Display & Sort Sheet

struct DisplaySortSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var searchConfig: SearchConfiguration
    
    private var hasNonDefaultSettings: Bool {
        searchConfig != SearchConfiguration.defaultConfig
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Display") {
                    Picker("Display Mode", selection: $searchConfig.displayMode) {
                        ForEach(SearchConfiguration.DisplayMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section("Sort") {
                    Picker("Sort By", selection: $searchConfig.sortField) {
                        ForEach(SearchConfiguration.SortField.allCases, id: \.self) { field in
                            Text(field.rawValue).tag(field)
                        }
                    }
                    
                    Picker("Sort Order", selection: $searchConfig.sortOrder) {
                        ForEach(SearchConfiguration.SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }
                
                Section {
                    Button(action: {
                        searchConfig.resetToDefaults()
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset to Defaults")
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(hasNonDefaultSettings ? .red : .gray)
                    }
                    .disabled(!hasNonDefaultSettings)
                }
            }
            .navigationTitle("Display & Sort")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "gearshape.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Settings coming soon")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Preference Key for Scroll Offset

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
