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
    @State private var showFilterSheet = false
    @State private var showSettingsSheet = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        ZStack(alignment: .top) {
            CardResultsView(filters: $filters)
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
                    onFilterTap: { showFilterSheet = true },
                    onSettingsTap: { showSettingsSheet = true }
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .safeAreaInset(edge: .bottom) {
            SearchBarView(
                filters: $filters,
                isSearchFocused: _isSearchFocused,
                onFilterSetTap: { showFilterSheet = true }
            )
        }
        .animation(.easeInOut(duration: 0.25), value: showTopBar)
        .sheet(isPresented: $showFilterSheet) {
            FilterSheetView()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsSheetView()
        }
    }
}

// MARK: - Top Bar

struct TopBarView: View {
    let onFilterTap: () -> Void
    let onSettingsTap: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onFilterTap) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
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

// MARK: - Filter Sheet

struct FilterSheetView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 60))
                    .foregroundStyle(.tint)
                
                Text("Filter Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Filter management coming soon")
                    .foregroundStyle(.secondary)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Filters")
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
