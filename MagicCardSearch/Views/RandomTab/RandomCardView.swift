import SwiftUI
import ScryfallKit
import SQLiteData
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "RandomCardView")

// MARK: - History Entry

private struct HistoryEntry: Identifiable {
    let id = UUID()
    let result: Result<Card, Error>

    var card: Card? {
        try? result.get()
    }
}

// MARK: - Scroll Item

private enum ScrollItem: Hashable {
    case intro
    case entry(UUID, Int)
    case placeholder
}

// MARK: - RandomCardView

struct RandomCardView: View {
    // FIXME: This is dumb as hell because in reality it's just a thunk that the parent can call.
    // A view model owned by the parent, so it can imperatively trigger advancement, would be the
    // right way to do this, but since it needs data stores injected and would have to watch its
    // own scroll position to reactively trigger loads, it's actually a huge pain in the ass to
    // implement. So we do this total nonsense.
    @Binding var advanceCard: Bool

    @State private var history: [HistoryEntry] = []
    @State private var scrollPosition: ScrollItem?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var filters = RandomCardFilters()
    @State private var showingFilterSheet = false
    @State private var fetchTask: Task<Void, Never>?

    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(RecentlyViewedCardsStore.self) private var recentlyViewedCardsStore
    @FetchAll private var bookmarks: [BookmarkedCard]

    private let client = ScryfallClient()

    private var currentCard: Card? {
        guard case .entry(_, let index) = scrollPosition else { return nil }
        return history[safe: index]?.card
    }

    // MARK: - Navigator

    var body: some View {
        GeometryReader { geometry in
            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    RandomCardOnboardingView()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .containerRelativeFrame(.horizontal)
                        .id(ScrollItem.intro)

                    ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                        Group {
                            switch entry.result {
                            case .success(let card):
                                CardDetailView(
                                    card: card,
                                    isFlipped: $cardFlipStates.for(card.id),
                                    searchState: nil,
                                )
                            case .failure(let error):
                                CardDetailView.Placeholder(
                                    name: nil,
                                    cornerRadius: 16,
                                    with: .error(error, nil),
                                )
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .containerRelativeFrame(.horizontal)
                        .id(ScrollItem.entry(entry.id, index))
                    }

                    CardDetailView.Placeholder(name: nil, cornerRadius: 16, with: .spinner)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .containerRelativeFrame(.horizontal)
                        .id(ScrollItem.placeholder)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $scrollPosition)
            .scrollIndicators(.hidden)
        }
        .navigationTitle(currentCard?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: filters != RandomCardFilters()
                          ? "line.3.horizontal.decrease.circle.fill"
                          : "line.3.horizontal.decrease.circle")
                }
            }

            if let card = currentCard {
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
        .onAppear {
            if history.isEmpty {
                fetchNextCard()
            }
        }
        .onChange(of: scrollPosition) {
            switch scrollPosition {
            case .intro, nil:
                break
            case .entry(_, let index):
                if index == history.count - 1 {
                    fetchNextCard()
                }
                if let card = history[safe: index]?.card {
                    recentlyViewedCardsStore.add(.init(card: card))
                }
            case .placeholder:
                fetchNextCard()
            }
        }
        .onChange(of: advanceCard) {
            guard advanceCard else { return }
            advanceCard = false
            withAnimation {
                switch scrollPosition {
                case .intro, nil:
                    if let first = history.first {
                        scrollPosition = .entry(first.id, 0)
                    } else {
                        scrollPosition = .placeholder
                    }
                case .entry(_, let index):
                    let nextIndex = index + 1
                    if let next = history[safe: nextIndex] {
                        scrollPosition = .entry(next.id, nextIndex)
                    } else {
                        scrollPosition = .placeholder
                    }
                case .placeholder:
                    break
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            NavigationStack {
                RandomCardFiltersView(filters: filters) { newFilters in
                    filters = newFilters
                    history = switch scrollPosition {
                    case .intro, nil:
                        []
                    case .entry(_, let index):
                        Array(history[0...index])
                    case .placeholder:
                        history
                    }
                    scrollPosition = .placeholder
                    fetchNextCard()
                }
            }
        }
    }

    private func fetchNextCard() {
        fetchTask?.cancel()
        fetchTask = Task {
            let entry: HistoryEntry
            do {
                let card = try await client.getRandomCard(query: filters.queryString)
                entry = HistoryEntry(result: .success(card))
            } catch {
                entry = HistoryEntry(result: .failure(error))
            }

            guard !Task.isCancelled else { return }

            history.append(entry)
            if case .placeholder = scrollPosition {
                scrollPosition = .entry(entry.id, history.count - 1)
            }
        }
    }
}
