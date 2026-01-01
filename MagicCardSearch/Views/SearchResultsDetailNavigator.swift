//
//  CardDetailNavigator.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//
import SwiftUI
import SwiftData
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    let list: ScryfallObjectList<Card>
    let initialIndex: Int
    @Binding var cardFlipStates: [UUID: Bool]

    @Environment(\.modelContext) private var modelContext
    @Query private var bookmarks: [BookmarkedCard]

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
                _ = list.loadNextPage()
            },
            onRetryNextPage: {
                _ = list.loadNextPage()
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
            if let bookmark = bookmarks.first(where: { $0.id == card.id }) {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modelContext.delete(bookmark)
                    } label: {
                        Image(systemName: "bookmark.fill")
                    }
                }
            } else {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        modelContext.insert(BookmarkedCard(from: card))
                    } label: {
                        Image(systemName: "bookmark")
                    }
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
