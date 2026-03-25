import SwiftUI
import ScryfallKit
import OSLog
import SQLiteData

private let recentSearchesSoftLimit = 8
private let recentSearchesHardLimit = 12

private struct RecentlyViewedSheetState: Identifiable {
    let id: UUID
    let index: Int
    let cards: [RecentlyViewedCard]

    init(index: Int, cards: [RecentlyViewedCard]) {
        self.index = index
        self.cards = cards
        self.id = cards.indices.contains(index) ? cards[index].id : UUID()
    }
}

private extension PinnedSearchEntry {
    var listId: String { "pinned:\(id ?? -1)" }
}

private extension SearchHistoryEntry {
    var listId: String { "history:\(id ?? -1)" }
}

struct SearchLandingView: View {
    let recentlyViewedCardWidth: CGFloat = 120
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    @Binding var searchState: SearchState

    @State private var showAllSearchHistory = false
    @State private var recentlyViewedSheetState: RecentlyViewedSheetState?

    @FetchAll(
        SearchHistoryEntry
            .order { $0.lastUsedAt.desc() }
            .where { !PinnedSearchEntry.select { $0.filters }.contains($0.filters) }
            .limit(recentSearchesHardLimit)
    )
    private var recentSearches

    @FetchOne(SearchHistoryEntry.count())
    private var recentSearchCount

    @FetchAll(PinnedSearchEntry.order { $0.pinnedAt.desc() })
    private var pinnedSearches

    @FetchAll(RecentlyViewedCard.order { $0.viewedAt.desc() }.limit(RecentlyViewedCardsStore.limit))
    private var recentlyViewedCards

    var body: some View {
        List {
            pinnedSearchesSection
            recentSearchesSection
            recentlyViewedCardsSection
            examplesSection
        }
        .contentMargins(.top, 20)
        .sheet(isPresented: $showAllSearchHistory) {
            AllSearchHistoryView(searchState: $searchState)
        }
        .sheet(item: $recentlyViewedSheetState) { state in
            FixedListCardDetailNavigatorView(
                cards: state.cards,
                initialIndex: state.index,
                searchState: $searchState,
                showCount: false,
            )
        }
    }

    @ViewBuilder
    private var pinnedSearchesSection: some View {
        if !pinnedSearches.isEmpty {
            Section {
                ForEach(pinnedSearches, id: \.listId) { entry in
                    Button {
                        searchState.filters = entry.filters
                        searchState.performSearch()
                    } label: {
                        HStack {
                            Text(entry.filters.plaintext)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.unpin(search: entry.filters)
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                        .tint(.orange)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(search: entry.filters)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .tint(.red)
                    }
                }
            } header: {
                Label("Pinned Searches", systemImage: "pin.fill")
            }
        }
    }

    private var isTruncatingRecentSearches: Bool {
        recentSearches.count >= recentSearchesHardLimit
    }

    private var visibleRecentSearches: [SearchHistoryEntry] {
        if isTruncatingRecentSearches {
            return Array(recentSearches.prefix(recentSearchesSoftLimit))
        }
        return recentSearches
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        if !recentSearches.isEmpty {
            Section {
                ForEach(visibleRecentSearches, id: \.listId) { entry in
                    Button {
                        searchState.filters = entry.filters
                        searchState.performSearch()
                    } label: {
                        HStack {
                            Text(entry.filters.plaintext)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(search: entry.filters)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        Button {
                            historyAndPinnedStore.pin(search: entry.filters)
                        } label: {
                            Label("Pin", systemImage: "pin")
                        }
                        .tint(.orange)
                    }
                }

                if isTruncatingRecentSearches {
                    Button {
                        showAllSearchHistory = true
                    } label: {
                        HStack {
                            Text("See all \(recentSearchCount ?? 0) searches...")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                HStack {
                    Label("Recent Searches", systemImage: "magnifyingglass")
                    Spacer()
                    Button(action: {
                        showAllSearchHistory = true
                    }) {
                        Text("View All")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var recentlyViewedCardsSection: some View {
        if !recentlyViewedCards.isEmpty {
            Section {} header: {
                Label("Recently Viewed Cards", systemImage: "rectangle.portrait.on.rectangle.portrait.angled")
                    .listRowInsets(.bottom, 0)
                    .listSectionMargins(.bottom, 0)
            }
            // Cute trick to put the real content in the header, from
            // https://stackoverflow.com/questions/79584292/how-to-make-the-first-row-in-a-swiftui-list-span-edge-to-edge-like-in-apple-heal
            // allows to have a non-rounded, edge-to-edge section.
            Section {} header: {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 8) {
                        ForEach(Array(recentlyViewedCards.enumerated()), id: \.element.id) { index, card in
                            CardView(
                                card: card,
                                quality: .normal,
                                isFlipped: .constant(false),
                                cornerRadius: 8,
                                showFlipButton: false,
                            )
                            .frame(width: recentlyViewedCardWidth)
                            .onTapGesture {
                                recentlyViewedSheetState = RecentlyViewedSheetState(
                                    index: index,
                                    cards: recentlyViewedCards
                                )
                            }
                        }
                    }
                    .padding(.horizontal, SearchTabConstants.horizontalPadding)
                }
                .scrollIndicators(.never)
                .listRowInsets(.horizontal, -SearchTabConstants.horizontalPadding)
                .listRowInsets(.vertical, 0)
                .listSectionMargins(.top, 0)
                .listSectionMargins(.horizontal, 0)
            }
        }
    }

    private var examplesSection: some View {
        Section {
            ForEach(ExampleSearch.dailyExamples, id: \.title) { example in
                Button {
                    searchState.filters = example.filters.map { .term($0) }
                    searchState.performSearch()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(example.title)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(example.filters.map { $0.description }.joined(separator: "   "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .id("example-\(example.title)")
            }
        } header: {
            Label("Need Inspiration?", systemImage: "lightbulb.max")
        }
    }
}
