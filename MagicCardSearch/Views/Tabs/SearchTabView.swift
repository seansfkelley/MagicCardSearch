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
                    DefaultSearchContent(
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
                suggestionLoadingState: $suggestionLoadingState,
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
    @Binding var suggestionLoadingState: DebouncedLoadingState
    @Binding var isSearchBarFocused: Bool

    @State private var showSyntaxReference = false

    var body: some View {
        NavigationStack {
            AutocompleteView(
                searchState: $searchState,
                suggestionLoadingState: $suggestionLoadingState,
            )
            .safeAreaInset(edge: .bottom) {
                SearchBarAndPillsView(
                    searchState: $searchState,
                    isFocused: $isSearchBarFocused,
                    isAutocompleteLoading: suggestionLoadingState.isLoadingDebounced,
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
            pinnedSearchesSection
            recentSearchesSection
            examplesSection
        }
        .contentMargins(.top, 20)
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
    private var recentSearchesSection: some View {
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
