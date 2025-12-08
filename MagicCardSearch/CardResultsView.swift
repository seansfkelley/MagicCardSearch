//
//  CardResultsView.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import SwiftUI

struct CardResultsView: View {
    var allowedToSearch: Bool
    @Binding var filters: [SearchFilter]
    @Binding var searchConfig: SearchConfiguration
    let globalFiltersSettings: GlobalFiltersSettings
    @State private var results: [CardResult] = []
    @State private var isLoading = false
    @State private var selectedCardIndex: Int?
    @State private var searchTask: Task<Void, Never>?
    
    private let service = CardSearchService()
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    var body: some View {
        ZStack {
            Group {
                if filters.isEmpty {
                    // Zero state: no filters added yet
                    ContentUnavailableView(
                        "Start Your Search",
                        systemImage: "text.magnifyingglass",
                        description: Text("Tap the search bar below and start typing to add filters")
                    )
                } else if results.isEmpty && !isLoading {
                    // Search performed but no results
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search filters")
                    )
                } else {
                    ScrollView {
                        Text("\(results.count) \(results.count == 1 ? "result" : "results")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, card in
                                CardResultCell(card: card)
                                    .onTapGesture {
                                        selectedCardIndex = index
                                    }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Loading overlay
            if isLoading {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .transition(.opacity)
                
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(.circular)
                    .tint(.white)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isLoading)
        .onChange(of: allowedToSearch) { _, _ in
            maybePerformSearch()
        }
        .onChange(of: filters) { _, _ in
            maybePerformSearch()
        }
        .onChange(of: searchConfig.uniqueMode) { _, _ in
            maybePerformSearch()
        }
        .onChange(of: searchConfig.sortField) { _, _ in
            maybePerformSearch()
        }
        .onChange(of: searchConfig.sortOrder) { _, _ in
            maybePerformSearch()
        }
        .task {
            maybePerformSearch()
        }
        .sheet(item: Binding(
            get: { selectedCardIndex.map { SheetIdentifier(index: $0) } },
            set: { selectedCardIndex = $0?.index }
        )) { identifier in
            CardDetailNavigator(
                cards: results,
                initialIndex: identifier.index
            )
        }
    }
    
    private func maybePerformSearch() {
        guard allowedToSearch else {
            return
        }
        
        // Cancel any existing search
        searchTask?.cancel()
        
        guard !filters.isEmpty else {
            results = []
            searchTask = nil
            return
        }
        
        print("Searching...")
        
        isLoading = true
        
        // Combine global filters (if enabled) with user filters
        var allFilters: [SearchFilter] = []
        if globalFiltersSettings.isEnabled {
            allFilters.append(contentsOf: globalFiltersSettings.filters)
        }
        allFilters.append(contentsOf: filters)
        
        searchTask = Task {
            do {
                results = try await service.search(
                    filters: allFilters,
                    config: searchConfig
                )
            } catch {
                // Only print error if task wasn't cancelled
                if !Task.isCancelled {
                    print("Search error: \(error)")
                }
                results = []
            }
            isLoading = false
        }
    }
}

// MARK: - Sheet Identifier

private struct SheetIdentifier: Identifiable {
    let index: Int
    var id: Int { index }
}

// MARK: - Card Result Cell

struct CardResultCell: View {
    let card: CardResult
    
    var body: some View {
        VStack {
            Group {
                if let imageUrl = card.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            placeholderView
                        @unknown default:
                            placeholderView
                        }
                    }
                } else {
                    placeholderView
                }
            }
            .aspectRatio(0.7, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
    }
    
    private var placeholderView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    
                    Text(card.name)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(8)
            )
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var filters: [SearchFilter] = [
            SearchFilter.keyValue("set", .equal, "7ED"),
            SearchFilter.keyValue("manavalue", .greaterThanOrEqual, "4")
        ]
        @State private var config = SearchConfiguration()
        
        var body: some View {
            CardResultsView(
                allowedToSearch: true,
                filters: $filters,
                searchConfig: $config,
                globalFiltersSettings: GlobalFiltersSettings()
            )
        }
    }
    
    return PreviewWrapper()
}
