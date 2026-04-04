import SwiftUI
import ScryfallKit
import SQLiteData
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "RandomCardView")

// MARK: - History Entry

private struct HistoryEntry: Identifiable {
    enum Content {
        case card(Card)
        case error(Error)
        case noResults
    }

    let id = UUID()
    let content: Content

    var card: Card? {
        if case .card(let card) = content { card } else { nil }
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

    @AppStorage("randomCardFilters") private var wrappedFilters = RawRepresentableWrapper(RandomCardFilters())
    var filters: RandomCardFilters { wrappedFilters.value }

    @State private var history: [HistoryEntry] = []
    @State private var scrollPosition: ScrollItem?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var showingFilterSheet = false
    @State private var fetchTask: Task<Void, Never>?
    private let onboardingFadeWidthFraction: CGFloat = 0.4
    @State var onboardingOpacity: CGFloat = 1

    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @Environment(RecentlyViewedCardsStore.self) private var recentlyViewedCardsStore
    @FetchAll private var bookmarks: [BookmarkedCard]

    private let client = ScryfallClient(logger: logger)

    private var currentCard: Card? {
        guard case .entry(_, let index) = scrollPosition else { return nil }
        return history[safe: index]?.card
    }

    private var isLastHistoryEntryNoResults: Bool {
        if case .noResults = history.last?.content { true } else { false }
    }

    // MARK: - Navigator

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RandomCardOnboardingView()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .opacity(onboardingOpacity)

                ScrollView(.horizontal) {
                    LazyHStack(spacing: 0) {
                        Color.clear
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .containerRelativeFrame(.horizontal)
                            .id(ScrollItem.intro)

                        ForEach(Array(history.enumerated()), id: \.element.id) { index, entry in
                            Group {
                                switch entry.content {
                                case .card(let card):
                                    CardDetailView(
                                        card: card,
                                        isFlipped: $cardFlipStates.for(card.id),
                                        searchState: nil,
                                    )
                                case .error(let error):
                                    CardDetailView.Placeholder(
                                        name: nil,
                                        cornerRadius: 16,
                                        with: .action(
                                            "exclamationmark.triangle",
                                            error.localizedDescription,
                                            nil,
                                        ),
                                    )
                                case .noResults:
                                    CardDetailView.Placeholder(
                                        name: nil,
                                        cornerRadius: 16,
                                        with: .action(
                                            "rectangle.portrait.slash",
                                            "No cards match your filters.",
                                            ("Change Filters", { showingFilterSheet = true }),
                                        ),
                                    )
                                }
                            }
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .containerRelativeFrame(.horizontal)
                            .id(ScrollItem.entry(entry.id, index))
                        }

                        if !isLastHistoryEntryNoResults {
                            CardDetailView.Placeholder(name: nil, cornerRadius: 16, with: .spinner)
                                .frame(width: geometry.size.width, height: geometry.size.height)
                                .containerRelativeFrame(.horizontal)
                                .id(ScrollItem.placeholder)
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollTargetBehavior(.paging)
                .scrollPosition(id: $scrollPosition)
                .scrollIndicators(.hidden)
                .onScrollGeometryChange(
                    for: CGFloat.self,
                    of: { scrollGeometry in
                        let x = scrollGeometry.contentOffset.x
                        let fadeWidth = geometry.size.width * onboardingFadeWidthFraction
                        return if x >= fadeWidth {
                            0
                        } else if x <= 0 {
                            1
                        } else {
                            (1 - x / fadeWidth)
                        }
                    },
                    action: { _, currentValue in
                        onboardingOpacity = currentValue
                    })
            }
        }
        .navigationTitle(currentCard?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingFilterSheet = true
                } label: {
                    Image(systemName: "line.3.horizontal.decrease")
                        .badge(filters != RandomCardFilters() ? " " : nil)
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
                if index == history.count - 1, !isLastHistoryEntryNoResults {
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
                    } else if !isLastHistoryEntryNoResults {
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
                    wrappedFilters = RawRepresentableWrapper(newFilters)
                    var preserved: [HistoryEntry] = switch scrollPosition {
                    case .intro, nil:
                        []
                    case .entry(_, let index):
                        Array(history[0...index])
                    case .placeholder:
                        history
                    }
                    if case .noResults = preserved.last?.content {
                        preserved = Array(preserved.dropLast())
                    }
                    history = preserved
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
                entry = HistoryEntry(content: .card(card))
            } catch let error as ScryfallKitError {
                guard !Task.isCancelled else { return }

                // When searching for cards, a 404 means "no results found", not an actual error.
                // Note that this condition assumes that we will never get legit 404s. This should
                // be fine since we only use a small number of fixed URLs, but of course it's not
                // foolproof if Scryfall makes breaking changes.
                if case .scryfallError(let scryfallError) = error, scryfallError.status == 404 {
                    logger.debug("intercepted Scryfall 404 and set to empty instead")
                    entry = HistoryEntry(content: .noResults)
                } else {
                    logger.error("failed to load random card with error=\(error)")
                    entry = HistoryEntry(content: .error(error))
                }
            } catch {
                guard !Task.isCancelled else { return }

                logger.error("failed to load random card with error=\(error)")
                entry = HistoryEntry(content: .error(error))
            }

            history.append(entry)
            if case .placeholder = scrollPosition {
                scrollPosition = .entry(entry.id, history.count - 1)
            }
        }
    }
}
