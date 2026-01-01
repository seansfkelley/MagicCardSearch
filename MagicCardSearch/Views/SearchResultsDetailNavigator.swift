//
//  CardDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    let list: ScryfallObjectList<Card>
    let initialIndex: Int
    @Binding var cardFlipStates: [UUID: Bool]
    
    @ObservedObject private var listManager = BookmarkedCardListManager.shared
    
    var body: some View {
        LazyPagingDetailNavigator(
            items: list.value.latestValue?.data ?? [],
            initialIndex: initialIndex,
            totalCount: list.value.latestValue?.totalCards ?? 0,
            hasMorePages: list.value.latestValue?.hasMore ?? false,
            isLoadingNextPage: list.value.isLoadingNextPage,
            nextPageError: list.value.nextPageError,
            loadDistance: 1,
            loader: { $0 },
            onNearEnd: {
                list.loadNextPage()
            },
            onRetryNextPage: {
                list.loadNextPage()
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
