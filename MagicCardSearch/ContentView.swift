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
                        HStack(alignment: .bottom) {
                            if !warnings.isEmpty {
                                WarningsPillView(
                                    warnings: warnings,
                                    isExpanded: $showWarningsPopover
                                )
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
            historyProvider.recordFilterUsage(filter)
            inputText = ""
            
        case .string(let string):
            inputText = string
        }
    }
}

// MARK: - Warnings Pill View

private struct WarningsPillView: View {
    let warnings: [String]
    @Binding var isExpanded: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isExpanded {
                ForEach(Array(warnings.enumerated()), id: \.offset) { index, warning in
                    Text(warning)
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .multilineTextAlignment(.leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    if index < warnings.count - 1 {
                        Divider()
                            .padding(.horizontal, 12)
                    }
                }
            } else {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        isExpanded = true
                    }
                } label: {
                    Text(warnings.count == 1 ? "1 warning" : "\(warnings.count) warnings")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                }
            }
        }
        .glassEffect(.regular.interactive(), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            if isExpanded {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded = false
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
