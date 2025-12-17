//
//  CardDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    let cards: [Card]
    let initialIndex: Int
    let totalCount: Int
    let hasMorePages: Bool
    let isLoadingNextPage: Bool
    let nextPageError: SearchErrorState?
    @Binding var cardFlipStates: [UUID: Bool]
    var onNearEnd: (() -> Void)?
    var onRetryNextPage: (() -> Void)?
    
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    
    init(cards: [Card],
         initialIndex: Int,
         totalCount: Int = 0,
         hasMorePages: Bool = false,
         isLoadingNextPage: Bool = false,
         nextPageError: SearchErrorState? = nil,
         cardFlipStates: Binding<[UUID: Bool]>,
         onNearEnd: (() -> Void)? = nil,
         onRetryNextPage: (() -> Void)? = nil) {
        self.cards = cards
        self.initialIndex = initialIndex
        self.totalCount = totalCount
        self.hasMorePages = hasMorePages
        self.isLoadingNextPage = isLoadingNextPage
        self.nextPageError = nextPageError
        self._cardFlipStates = cardFlipStates
        self.onNearEnd = onNearEnd
        self.onRetryNextPage = onRetryNextPage
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
            onNearEnd: onNearEnd,
            onRetryNextPage: onRetryNextPage
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
