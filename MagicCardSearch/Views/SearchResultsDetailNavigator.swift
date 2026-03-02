import SwiftUI
import SQLiteData
import ScryfallKit

struct SearchResultsDetailNavigator: View {
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(\.dismiss) private var dismiss

    let list: ScryfallObjectList<Card>
    let initialIndex: Int
    @Binding var cardFlipStates: [UUID: Bool]
    @Binding var searchState: SearchState

    @FetchAll private var bookmarks: [BookmarkedCard]
    @State private var navigatorIndex: Int

    init(list: ScryfallObjectList<Card>, initialIndex: Int, cardFlipStates: Binding<[UUID: Bool]>, searchState: Binding<SearchState>) {
        self.list = list
        self.initialIndex = initialIndex
        self._cardFlipStates = cardFlipStates
        self._searchState = searchState
        self._navigatorIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        let totalCount = list.value.latestValue?.totalCards ?? 0

        LazyPagingDetailNavigator(
            items: list.value.latestValue?.data ?? [],
            currentIndex: $navigatorIndex,
            hasMorePages: list.value.latestValue?.hasMore ?? false,
            isLoadingNextPage: list.value.isLoadingNextPage,
            nextPageError: list.value.nextPageError,
            loadDistance: 1,
            loader: { $0 },
            onNearEnd: { list.loadNextPage() },
            onRetryNextPage: { list.loadNextPage() },
        ) { card in
            CardDetailView(
                card: card,
                isFlipped: Binding(
                    get: { cardFlipStates[card.id] ?? false },
                    set: { cardFlipStates[card.id] = $0 }
                ),
                searchState: $searchState,
            )
        } toolbarContent: { card in
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }

            if let card {
                if bookmarks.contains(where: { $0.id == card.id }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.unbookmark(id: card.id)
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.bookmark(card: card)
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
        } bottomContent: { index, count in
            Text("\(index + 1) of \(totalCount > 0 ? totalCount : count)")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 20)
        }
    }
}
