//
//  CardDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    let state: ScryfallSearchResultsList
    let initialIndex: Int
    @Binding var cardFlipStates: [UUID: Bool]
    
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    
    init(
        state: ScryfallSearchResultsList,
        initialIndex: Int,
        cardFlipStates: Binding<[UUID: Bool]>
    ) {
        self.state = state
        self.initialIndex = initialIndex
        self._cardFlipStates = cardFlipStates
    }
    
    private var results: LoadableResult<SearchResults, SearchErrorState> {
        state.current
    }
    
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
            onNearEnd: {
                state.loadNextPageIfNeeded()
            },
            onRetryNextPage: {
                state.retryNextPage()
            }
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
}
