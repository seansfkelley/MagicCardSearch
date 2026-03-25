import SwiftUI
import ScryfallKit
import SQLiteData
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "FixedListCardDetailNavigatorView")

struct FixedListCardDetailNavigatorView<C: CardDisplayable & Identifiable<UUID>>: View {
    @Environment(RecentlyViewedCardsStore.self) private var recentlyViewedCardsStore

    private enum LoadingState {
        case loading(Task<Void, Never>)
        case loaded(Card)
        case failed(Error)
    }

    let cards: [C]
    let searchState: Binding<SearchState>?
    let showCount: Bool

    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var scrollIndex: Int?
    @State private var loadedCards: [UUID: LoadingState] = [:]

    @FetchAll private var allBookmarks: [BookmarkedCard]
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(\.dismiss) private var dismiss

    private let cardSearchService = CardSearchService()

    init(cards: [C], initialIndex: Int, searchState: Binding<SearchState>?, showCount: Bool = true) {
        self.cards = cards
        self.searchState = searchState
        self._scrollIndex = State(initialValue: initialIndex)
        self.showCount = showCount
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                            cardView(for: card)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .containerRelativeFrame(.horizontal)
                                .id(index)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollIndex)
                .scrollIndicators(.hidden)
            }
            .navigationTitle(cards[safe: scrollIndex ?? -1]?.frontFace.name ?? "Loading...")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                }

                if let currentCard = cards[safe: scrollIndex ?? -1] {
                    if allBookmarks.contains(where: { $0.id == currentCard.id }) {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                bookmarkedCardsStore.unbookmark(id: currentCard.id)
                            } label: {
                                Image(systemName: "bookmark.fill")
                            }
                        }
                    } else {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button {
                                if case .loaded(let card) = loadedCards[currentCard.id] {
                                    bookmarkedCardsStore.bookmark(card: card)
                                }
                            } label: {
                                Image(systemName: "bookmark")
                            }
                        }
                    }

                    if case .loaded(let card) = loadedCards[currentCard.id],
                       let url = URL(string: card.scryfallUri) {
                        ToolbarItem(placement: .topBarTrailing) {
                            ShareLink(item: url)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if showCount {
                    Text("\((scrollIndex ?? 0) + 1) of \(cards.count)")
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .glassEffect(.regular, in: .capsule)
                        .padding(.bottom, 20)
                }
            }
        }
        .onAppear {
            if let scrollIndex, let card = cards[safe: scrollIndex] {
                load(card: card)
                recentlyViewedCardsStore.add(.init(card: card))
            }
        }
        .onChange(of: scrollIndex) {
            if let scrollIndex, let card = cards[safe: scrollIndex] {
                load(card: card)
                recentlyViewedCardsStore.add(.init(card: card))
            }
        }
    }

    @ViewBuilder
    private func cardView(for card: C) -> some View {
        switch loadedCards[card.id] {
        case .loaded(let fullCard):
            CardDetailView(card: fullCard, isFlipped: $cardFlipStates.for(card.id), searchState: searchState)
        case .loading:
            CardDetailView.Placeholder(name: card.frontFace.name, cornerRadius: 16, with: .spinner)
        case .failed(let error):
            CardDetailView.Placeholder(name: card.frontFace.name, cornerRadius: 16, with: .error(error, { load(card: card) }))
        case nil:
            CardDetailView.Placeholder(name: card.frontFace.name, cornerRadius: 16, with: .spinner)
                .onAppear { load(card: card) }
        }
    }

    private func load(card: C) {
        switch loadedCards[card.id] {
        case .loaded, .loading:
            return
        default:
            break
        }

        let task = Task {
            do {
                logger.info("fetching card id=\(card.id)")
                let loaded = try await cardSearchService.fetchCard(byScryfallId: card.id)
                guard !Task.isCancelled else { return }
                await MainActor.run { loadedCards[card.id] = .loaded(loaded) }
            } catch is CancellationError {
                // nop
            } catch {
                await MainActor.run { loadedCards[card.id] = .failed(error) }
            }
        }

        loadedCards[card.id] = .loading(task)
    }
}
