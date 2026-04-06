import SwiftUI
import SQLiteData
import ScryfallKit

struct LazyPagingCardDetailNavigatorView: View {
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(RecentlyViewedCardsStore.self) private var recentlyViewedCardsStore
    @Environment(\.dismiss) private var dismiss

    let list: ScryfallObjectList<Card>
    @Binding var cardFlipStates: [UUID: Bool]
    var searchState: Binding<SearchState>?

    @FetchAll private var bookmarks: [BookmarkedCard]
    @State private var scrollIndex: Int?

    private let pagePreloadDistance = 3

    init(
        list: ScryfallObjectList<Card>,
        initialIndex: Int,
        cardFlipStates: Binding<[UUID: Bool]>,
        searchState: Binding<SearchState>?,
    ) {
        self.list = list
        self._cardFlipStates = cardFlipStates
        self.searchState = searchState
        self._scrollIndex = State(initialValue: initialIndex)
    }

    var body: some View {
        let items = list.value.latestValue?.data ?? []
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, card in
                        CardDetailView(
                            card: card,
                            isFlipped: $cardFlipStates.for(card.id),
                            searchState: searchState,
                        )
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .containerRelativeFrame(.horizontal)
                        .id(index)
                    }

                    if list.value.latestValue?.hasMore ?? false || list.value.isLoadingNextPage || list.value.nextPageError != nil {
                        paginationStatusPage(geometry: geometry).id(items.count)
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollIndex)
            .scrollIndicators(.hidden)
        }
        .navigationTitle(list.value.latestValue?.data[safe: scrollIndex ?? -1]?.name ?? "Loading...")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                }
            }

            if let card = items[safe: scrollIndex ?? -1] {
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
        }
        .safeAreaInset(edge: .bottom) {
            Text("\((scrollIndex ?? 0) + 1) of \(list.value.latestValue?.totalCards ?? items.count)")
                .font(.caption)
                .foregroundStyle(.primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .glassEffect(.regular, in: .capsule)
                .padding(.bottom, 20)
        }
        .onChange(of: scrollIndex, initial: true) {
            if let scrollIndex {
                if scrollIndex > items.count - pagePreloadDistance {
                    list.loadNextPage()
                }
                if let card = items[safe: scrollIndex] {
                    recentlyViewedCardsStore.add(.init(card: card))
                }
            }
        }
        .onChange(of: items.count) { _, newCount in
            if let scrollIndex, scrollIndex > newCount {
                self.scrollIndex = newCount
                list.loadNextPage()
            }
        }
    }

    @ViewBuilder
    private func paginationStatusPage(geometry: GeometryProxy) -> some View {
        VStack(spacing: 20) {
            if list.value.isLoadingNextPage {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading more results...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            } else if let error = list.value.nextPageError {
                VStack(spacing: 20) {
                    Image(systemName: error.iconName)
                        .font(.system(size: 50))
                        .foregroundStyle(.secondary)

                    VStack(spacing: 8) {
                        Text(error.title)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(error.description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }

                    Button("Retry") {
                        list.loadNextPage()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            } else {
                // This case shouldn't happen, but show loading as fallback
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("Loading more results...")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: geometry.size.width, height: geometry.size.height)
        .containerRelativeFrame(.horizontal)
    }
}
