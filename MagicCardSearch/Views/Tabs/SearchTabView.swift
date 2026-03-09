import SwiftUI
import ScryfallKit
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchTabView")

private extension PinnedSearchEntry {
    var listId: String { "pinned:\(id ?? -1)" }
}

private extension SearchHistoryEntry {
    var listId: String { "history:\(id ?? -1)" }
}

struct SearchTabView: View {
    @Binding var searchState: SearchState

    @State private var showSearchSheet = false
    @State private var showDisplayOptionsSheet = false
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var showAllSearchHistory = false
    @State private var isSearchBarFocused = false

    var body: some View {
        NavigationStack {
            Group {
                if let results = searchState.results {
                    SearchResultsGridView(list: results, searchState: $searchState)
                } else {
                    SearchLandingView(
                        searchState: $searchState,
                        showAllSearchHistory: $showAllSearchHistory,
                    )
                }
            }
            .safeAreaInset(edge: .bottom) {
                FakeSearchBarButtonView(searchState: $searchState) {
                    showSearchSheet = true
                }
                .padding(.bottom)
                .padding(.horizontal, 20) // trying to match the tab bar width
            }
            .toolbar {
                if searchState.results != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            pendingSearchConfig = searchState.configuration
                            showDisplayOptionsSheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(
                            item: CardSearchService
                                .buildSearchURL(
                                    filters: searchState.filters,
                                    config: searchState.configuration,
                                    forAPI: false
                                ) ?? URL(string: "https://scryfall.com")!
                        ) {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: searchState.filters) { _, newFilters in
            searchState.results?.clearWarnings()
            if newFilters.isEmpty {
                searchState.results = nil
            }
        }
        .onChange(of: searchState.searchNonce) {
            showSearchSheet = false
        }
        .sheet(isPresented: $showSearchSheet) {
            SearchSheetView(
                searchState: $searchState,
                isSearchBarFocused: $isSearchBarFocused,
            )
        }
        .sheet(isPresented: $showDisplayOptionsSheet, onDismiss: {
            if let pending = pendingSearchConfig, pending != searchState.configuration {
                searchState.configuration = pending
                searchState.performSearch()
                searchState.configuration.save()
            }
            pendingSearchConfig = nil
        }) {
            DisplayOptionsView(searchConfig: Binding(
                get: { pendingSearchConfig ?? searchState.configuration },
                set: { pendingSearchConfig = $0 }
            ))
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showAllSearchHistory) {
            AllSearchHistoryView(searchState: $searchState)
        }
    }
}

// MARK: - Search Sheet

private struct SearchSheetView: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var searchState: SearchState
    @Binding var isSearchBarFocused: Bool

    @State private var showSyntaxReference = false

    var body: some View {
        NavigationStack {
            AutocompleteView(
                searchState: $searchState,
            )
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(
                    searchState: $searchState,
                    isFocused: $isSearchBarFocused,
                )
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Image(systemName: "book")
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showSyntaxReference) {
            SyntaxReferenceView()
        }
    }
}

// MARK: - Default Search Content

private let recentSearchesSoftLimit = 8
private let recentSearchesHardLimit = 12

private struct SearchLandingView: View {
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore
    @Binding var searchState: SearchState
    @Binding var showAllSearchHistory: Bool

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

    @State private var recentlyViewedSheetState: RecentlyViewedSheetState?

    var body: some View {
        List {
            pinnedSearchesSection
            recentSearchesSection
            recentlyViewedCardsSection
            examplesSection
        }
        .contentMargins(.top, 20)
        .sheet(item: $recentlyViewedSheetState) { state in
            FixedListCardDetailNavigatorView(
                cards: state.cards,
                initialIndex: state.index,
                searchState: $searchState
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
                            Text(entry.filters.map { $0.description }.joined(separator: " "))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
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
                            Text(entry.filters.map { $0.description }.joined(separator: " "))
                                .font(.body)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
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
                    Label("Recent Searches", systemImage: "clock.arrow.circlepath")
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
                Label("Recently Viewed", systemImage: "clock")
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
                                showFlipButton: false
                            )
                            .frame(width: 120)
                            .onTapGesture {
                                recentlyViewedSheetState = RecentlyViewedSheetState(
                                    index: index,
                                    cards: recentlyViewedCards
                                )
                            }
                        }
                    }
                }
                .scrollIndicators(.never)
                .frame(height: 120 / Card.aspectRatio)
                .listRowInsets(.all, 0)
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
                            Text(example.filters.map { $0.description }.joined(separator: " "))
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
// MARK: - Recently Viewed Sheet State

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
