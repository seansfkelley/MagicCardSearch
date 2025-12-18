//
//  CardDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    @Binding var results: LoadableResult<SearchResults, SearchErrorState>
    let initialIndex: Int
    @Binding var cardFlipStates: [UUID: Bool]
    
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    private let searchService = CardSearchService()
    
    private var cards: [Card] {
        results.latestValue?.cards ?? []
    }
    
    private var totalCount: Int {
        results.latestValue?.totalCount ?? 0
    }
    
    private var hasMorePages: Bool {
        results.latestValue?.nextPageUrl != nil
    }
    
    private var isLoadingNextPage: Bool {
        results.isLoadingNextPage
    }
    
    private var nextPageError: SearchErrorState? {
        results.nextPageError
    }
    
    var body: some View {
        LazyPagingDetailNavigator(
            items: cards,
            initialIndex: initialIndex,
            totalCount: totalCount,
            hasMorePages: hasMorePages,
            isLoadingNextPage: isLoadingNextPage,
            nextPageError: nextPageError,
            loadDistance: 1,
            loader: { $0 },
            onNearEnd: loadNextPageIfNeeded,
            onRetryNextPage: retryNextPage
        ) { card in
            CardDetailView(
                card: card,
                isFlipped: Binding(
                    get: { cardFlipStates[card.id] ?? false },
                    set: { cardFlipStates[card.id] = $0 }
                )
            )
        } toolbarContent: { card in
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    let listItem = BookmarkedCard(from: card)
                    listManager.toggleCard(listItem)
                } label: {
                    Image(
                        systemName: listManager.contains(cardWithId: card.id)
                            ? "bookmark.fill" : "bookmark"
                    )
                }
            }

            if let url = URL(string: card.scryfallUri) {
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: url)
                }
            }
        }
    }
    
    private func loadNextPageIfNeeded() {
        guard case .loaded(let searchResults, _) = results,
              let nextUrl = searchResults.nextPageUrl else {
            return
        }

        print("Loading next page \(nextUrl)")

        results = .loading(searchResults, nil)

        Task {
            do {
                let searchResult = try await searchService.fetchNextPage(from: nextUrl)
                let updatedResults = SearchResults(
                    totalCount: searchResults.totalCount,
                    cards: searchResults.cards + searchResult.cards,
                    warnings: searchResults.warnings,
                    nextPageUrl: searchResult.nextPageURL
                )
                results = .loaded(updatedResults, nil)
            } catch {
                print("Error loading next page: \(error)")
                results = .errored(searchResults, SearchErrorState(from: error))
            }
        }
    }

    private func retryNextPage() {
        // Clear the error and retry
        if case .errored(let value, _) = results, let searchResults = value {
            results = .loaded(searchResults, nil)
            loadNextPageIfNeeded()
        }
    }
}
