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
    @State private var results: [CardResult] = []
    @State private var totalCount: Int = 0
    @State private var nextPageURL: String?
    @State private var isLoading = false
    @State private var isLoadingNextPage = false
    @State private var nextPageError: SearchErrorState?
    @State private var selectedCardIndex: Int?
    @State private var searchTask: Task<Void, Never>?
    @State private var errorState: SearchErrorState?
    
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
                } else if let error = errorState {
                    // Error state
                    errorView(for: error)
                } else if results.isEmpty && !isLoading {
                    // Search performed but no results
                    ContentUnavailableView(
                        "No Results",
                        systemImage: "magnifyingglass",
                        description: Text("Try adjusting your search filters")
                    )
                } else {
                    ScrollView {
                        Text("\(totalCount) \(totalCount == 1 ? "result" : "results")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, card in
                                CardResultCell(card: card)
                                    .onTapGesture {
                                        selectedCardIndex = index
                                    }
                                    .onAppear {
                                        // Load next page when nearing the end
                                        if index == results.count - 4 {
                                            loadNextPageIfNeeded()
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Pagination status section
                        if nextPageURL != nil || isLoadingNextPage || nextPageError != nil {
                            paginationStatusView
                                .padding(.horizontal)
                                .padding(.vertical, 20)
                        } else {
                            // Add bottom padding when no pagination status
                            Color.clear
                                .frame(height: 20)
                        }
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
                initialIndex: identifier.index,
                totalCount: totalCount,
                hasMorePages: nextPageURL != nil,
                isLoadingNextPage: isLoadingNextPage,
                nextPageError: nextPageError,
                onNearEnd: {
                    loadNextPageIfNeeded()
                },
                onRetryNextPage: {
                    retryNextPage()
                }
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
            totalCount = 0
            nextPageURL = nil
            errorState = nil
            searchTask = nil
            return
        }
        
        print("Searching...")
        
        isLoading = true
        errorState = nil
        
        searchTask = Task {
            do {
                let searchResult = try await service.search(
                    filters: filters,
                    config: searchConfig
                )
                results = searchResult.cards
                totalCount = searchResult.totalCount
                nextPageURL = searchResult.nextPageURL
                errorState = nil
            } catch {
                // Only handle error if task wasn't cancelled
                if !Task.isCancelled {
                    print("Search error: \(error)")
                    errorState = SearchErrorState(from: error)
                }
                results = []
                totalCount = 0
                nextPageURL = nil
            }
            isLoading = false
        }
    }
    
    private func loadNextPageIfNeeded() {
        // Don't load if already loading or no more pages
        guard !isLoadingNextPage, let nextURL = nextPageURL else {
            return
        }
        
        // Don't load if there's already an error showing
        guard nextPageError == nil else {
            return
        }
        
        print("Loading next page...")
        print(nextURL)
        
        isLoadingNextPage = true
        
        Task {
            do {
                let searchResult = try await service.fetchNextPage(from: nextURL)
                results.append(contentsOf: searchResult.cards)
                nextPageURL = searchResult.nextPageURL
                nextPageError = nil
            } catch {
                print("Error loading next page: \(error)")
                nextPageError = SearchErrorState(from: error)
            }
            isLoadingNextPage = false
        }
    }
    
    private func retryNextPage() {
        nextPageError = nil
        loadNextPageIfNeeded()
    }
    
    @ViewBuilder
    private var paginationStatusView: some View {
        VStack(spacing: 16) {
            if isLoadingNextPage {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading more results...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else if let error = nextPageError {
                VStack(spacing: 16) {
                    Image(systemName: error.iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 4) {
                        Text(error.title)
                            .font(.headline)
                        Text(error.description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    Button("Retry") {
                        retryNextPage()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
    }
    
    @ViewBuilder
    private func errorView(for errorState: SearchErrorState) -> some View {
        ContentUnavailableView {
            Label(errorState.title, systemImage: errorState.iconName)
        } description: {
            Text(errorState.description)
        } actions: {
            Button("Try Again") {
                maybePerformSearch()
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Search Error State



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
                if let imageUrl = card.smallImageUrl, let url = URL(string: imageUrl) {
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
                searchConfig: $config
            )
        }
    }
    
    return PreviewWrapper()
}
