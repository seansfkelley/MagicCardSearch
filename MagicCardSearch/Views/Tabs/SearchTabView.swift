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

    @State private var suggestionLoadingState = DebouncedLoadingState()
    @State private var showSyntaxReference = false
    @State private var showDisplaySheet = false
    @State private var pendingSearchConfig: SearchConfiguration?
    @State private var showAllSearchHistory = false

    private var hasActiveSearch: Bool {
        searchState.results != nil && !searchState.filters.isEmpty
    }

    private var showAutocomplete: Bool {
        !searchState.searchText.isEmpty || !searchState.filters.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(uiColor: .systemBackground)
                    .ignoresSafeArea()

                if hasActiveSearch {
                    searchResultsContent
                } else if showAutocomplete {
                    autocompleteContent
                } else {
                    defaultContent
                }
            }
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(
                    searchState: $searchState,
                    isAutocompleteLoading: suggestionLoadingState.isLoadingDebounced,
                )
            }
            .toolbar {
                if hasActiveSearch {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            pendingSearchConfig = searchState.configuration
                            showDisplaySheet = true
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSyntaxReference = true
                    } label: {
                        Image(systemName: "book")
                    }
                }

                if !hasActiveSearch {
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            searchState.performSearch()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .buttonStyle(.glassProminent)
                    }
                }

                if hasActiveSearch {
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
        .sheet(isPresented: $showDisplaySheet, onDismiss: {
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
        .sheet(isPresented: $showSyntaxReference) {
            SyntaxReferenceView()
        }
        .sheet(isPresented: $showAllSearchHistory) {
            AllSearchHistoryView(searchState: $searchState)
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsContent: some View {
        if let results = searchState.results {
            SearchResultsGridView(list: results, searchState: $searchState)
        }
    }

    // MARK: - Autocomplete

    private var autocompleteContent: some View {
        AutocompleteView(
            searchState: $searchState,
            suggestionLoadingState: $suggestionLoadingState,
        )
    }

    // MARK: - Default Content (pinned, recent, examples)

    private var defaultContent: some View {
        DefaultSearchContent(
            searchState: $searchState,
            showAllSearchHistory: $showAllSearchHistory,
        )
    }
}

// MARK: - Default Search Content

private struct DefaultSearchContent: View {
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore
    @Binding var searchState: SearchState
    @Binding var showAllSearchHistory: Bool

    @FetchAll(
        SearchHistoryEntry
            .order { $0.lastUsedAt.desc() }
            .where { !PinnedSearchEntry.select { $0.filters }.contains($0.filters) }
            .limit(10)
    )
    private var recentSearches

    @FetchAll(PinnedSearchEntry.order { $0.pinnedAt.desc() })
    var pinnedSearches

    var body: some View {
        List {
            pinnedSearchesSection()
            recentSearchesSection()
            examplesSection()
        }
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
