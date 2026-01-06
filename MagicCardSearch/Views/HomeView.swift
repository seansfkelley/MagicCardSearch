import SwiftUI
import ScryfallKit
import Logging
import SQLiteData

private let logger = Logger(label: "HomeView")

private struct PlainStyling: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.body)
            .textCase(.none)
            .foregroundStyle(.primary)
            .listRowInsets(.init(top: 10, leading: 0, bottom: 10, trailing: 0))
    }
}

private extension View {
    func plainStyling() -> some View {
        modifier(PlainStyling())
    }
}

private extension PinnedSearchEntry {
    var listId: String { "pinned:\(id ?? -1)" }
}

private extension SearchHistoryEntry {
    var listId: String { "history:\(id ?? -1)" }
}

struct HomeView: View {
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore
    @Binding var searchState: SearchState

    @FetchAll(
        SearchHistoryEntry
            .order { $0.lastUsedAt.desc() }
            .where { !PinnedSearchEntry.select { $0.filters }.contains($0.filters) }
            .limit(10)
    )
    private var recentSearches
    
    @FetchAll(PinnedSearchEntry.order { $0.pinnedAt.desc() })
    var pinnedSearches
    
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var selectedFeaturedCardIndex: Int?
    @State private var showAllSearchHistory = false
    
    private let featuredList = FeaturedCardsObjectList.shared
    private let featuredCardWidth: CGFloat = 120

    var body: some View {
        List {
            featuredCardsSection()
            pinnedSearchesSection()
            recentSearchesSection()
            examplesSection()
        }
        .task {
            if isRunningTests() {
                logger.info("skipping featured card load in test environment")
            } else {
                FeaturedCardsObjectList.shared.loadNextPage()
            }
        }
        .sheet(
            item: Binding(
                get: { selectedFeaturedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedFeaturedCardIndex = $0?.index }
            )
        ) { identifier in
            SearchResultsDetailNavigator(
                list: FeaturedCardsObjectList.shared,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates,
                searchState: $searchState,
            )
        }
        .sheet(isPresented: $showAllSearchHistory) {
            AllSearchHistoryView(searchState: $searchState)
        }
        .onChange(of: searchState.searchNonce) {
            showAllSearchHistory = false
        }
    }

    @ViewBuilder
    private func featuredCardsSection() -> some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    switch FeaturedCardsObjectList.shared.value {
                    case .loading(nil, _), .unloaded:
                        ForEach(0..<15, id: \.self) { _ in
                            CardPlaceholderView(name: nil, cornerRadius: 8, withSpinner: true)
                                .frame(width: featuredCardWidth, height: featuredCardWidth / Card.aspectRatio)
                        }
                    case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                        ForEach(Array(results.data.enumerated()), id: \.element.id) { index, card in
                            Button {
                                selectedFeaturedCardIndex = index
                            } label: {
                                CardView(
                                    card: card,
                                    quality: .small,
                                    isFlipped: Binding(
                                        get: { cardFlipStates[card.id] ?? false },
                                        set: { cardFlipStates[card.id] = $0 }
                                    ),
                                    cornerRadius: 8,
                                )
                                .frame(width: featuredCardWidth)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if index == results.data.count - 3 {
                                    featuredList.loadNextPage()
                                }
                            }
                        }

                        if case .loading = featuredList.value, results.hasMore ?? false {
                            ProgressView()
                                .frame(width: featuredCardWidth, height: featuredCardWidth / Card.aspectRatio)
                        }
                    case .errored(nil, let error):
                        ContentUnavailableView(
                            "Unable to Load Spoilers",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error.description),
                        )
                        .frame(width: featuredCardWidth * 2, height: featuredCardWidth / Card.aspectRatio)
                    }
                }
                .padding(.horizontal)
            }
        } header: {
            HStack {
                Label("Recent Spoilers", systemImage: "sparkles")

                Spacer()

                Button(action: {
                    searchState.filters = [
                        .basic(false, "date", .greaterThanOrEqual, "today"),
                        .basic(false, "order", .including, SortMode.spoiled.rawValue),
                        .basic(false, "dir", .including, SortDirection.desc.rawValue),
                        .basic(false, "unique", .including, UniqueMode.prints.rawValue),
                    ]
                    searchState.performSearch()
                }) {
                    Text("View All")
                }
            }
            .padding(.horizontal)
        }
        .listRowInsets(.horizontal, 0)
        .listSectionMargins(.horizontal, 0)
    }

    @ViewBuilder
    private func pinnedSearchesSection() -> some View {
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
                        .padding(.horizontal)
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
                    .padding(.horizontal)
            }
            .listRowInsets(.horizontal, 0)
            .listSectionMargins(.horizontal, 0)
        }
    }

    @ViewBuilder
    private func recentSearchesSection() -> some View {
        if !recentSearches.isEmpty {
            Section {
                ForEach(recentSearches, id: \.listId) { entry in
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
                        .padding(.horizontal)
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
                .padding(.horizontal)
            }
            .listRowInsets(.horizontal, 0)
            .listSectionMargins(.horizontal, 0)
        }
    }

    @ViewBuilder
    private func examplesSection() -> some View {
        Section {
            ForEach(ExampleSearch.dailyExamples, id: \.title) { example in
                Button {
                    searchState.filters = example.filters
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
                    .padding(.horizontal)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .id("example-\(example.title)")
            }
        } header: {
            Label("Need Inspiration?", systemImage: "lightbulb.max")
                .padding(.horizontal)
        }
        .listRowInsets(.horizontal, 0)
        .listSectionMargins(.horizontal, 0)
    }
}
// MARK: - Featured Cards State

@MainActor
@Observable
private class FeaturedCardsObjectList: ScryfallObjectList<Card> {
    private static let scryfall = ScryfallClient(networkLogLevel: .minimal)

    static let shared = FeaturedCardsObjectList { page async throws in
        return try await scryfall.searchCards(
            query: "date>=today",
            unique: .prints,
            order: .spoiled,
            sortDirection: .desc,
            page: page,
        )
    }
}
