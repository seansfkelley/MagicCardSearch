import SwiftUI
import SQLiteData
import FuzzyMatch

private enum TimeInterval: CaseIterable {
    case today
    case yesterday
    case pastWeek
    case pastMonth
    case older

    var displayName: String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .pastWeek: return "Past Week"
        case .pastMonth: return "Past Month"
        case .older: return "Older"
        }
    }
}

private let fuzzyMatchConfig = MatchConfig(
    minScore: 0.85,
    // Default seems better tuned to phrase-sized terms, which these are, rather than individual
    // words, which is how it's tuned for the autocomplete.
    algorithm: .editDistance(.default)
)

private struct SearchHistorySuggestion {
    let content: SearchHistoryEntry
    let string: String
    let highlights: [Range<String.Index>]
    let rawScore: Double
    let biasedScore: Double
}

struct AllSearchHistoryView: View {
    private let buttonSize: CGFloat = 44

    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore
    @Binding var searchState: SearchState

    @FetchAll(SearchHistoryEntry.order { $0.lastUsedAt.desc() })
    var searchHistory

    @FetchAll
    var pinnedSearches: [PinnedSearchEntry]

    @State private var editMode: EditMode = .inactive
    @State private var selectedSearches: Set<Int64?> = []
    @State private var filterText: String = ""
    @FocusState private var isSearchFocused: Bool

    private var isEditing: Bool {
        return editMode == .active
    }

    var body: some View {
        NavigationStack {
            // HStack doesn't do anything except wrap the real content and maintain its own
            // identity, which makes sure the main view doesn't get unmounted and remounted, which
            // throws out focus state, every time it switches modes.
            HStack {
                if searchHistory.isEmpty {
                    ContentUnavailableView(
                        "No Recent Searches",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your search history will appear here.")
                    )
                } else if isSearchFocused {
                    FilteredSearchHistoryList(
                        searchHistory: searchHistory,
                        pinnedSearches: pinnedSearches,
                        filterText: filterText,
                        searchState: $searchState
                    )
                } else {
                    GroupedSearchHistoryList(
                        searchHistory: searchHistory,
                        pinnedSearches: pinnedSearches,
                        editMode: $editMode,
                        selectedSearches: $selectedSearches,
                        searchState: $searchState
                    )
                }
            }
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isEditing {
                        if selectedSearches.count == searchHistory.count {
                            Button {
                                withAnimation {
                                    selectedSearches.removeAll()
                                }
                            } label: {
                                Text("Deselect All")
                            }
                        } else {
                            Button {
                                withAnimation {
                                    selectedSearches = Set(searchHistory.map(\.id))
                                }
                            } label: {
                                Text("Select All")
                            }
                        }
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }

                if isEditing {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode = .inactive
                                selectedSearches.removeAll()
                            }
                        } label: {
                            Text("Done")
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        Spacer()

                        Button(role: .destructive) {
                            withAnimation {
                                let filtersToDelete = searchHistory
                                    .filter { selectedSearches.contains($0.id) }
                                    .map(\.filters)
                                historyAndPinnedStore.delete(searches: filtersToDelete)
                                selectedSearches.removeAll()
                                editMode = .inactive
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        .disabled(selectedSearches.isEmpty)
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            withAnimation {
                                editMode = .active
                            }
                        } label: {
                            Image(systemName: "checklist")
                        }
                        .disabled(searchHistory.isEmpty || isSearchFocused)
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !isEditing {
                    HStack {
                        SearchBarLayout {
                            TextField("Filter searches...", text: $filterText)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .textContentType(.none)
                                .focused($isSearchFocused)
                        }
                        .frame(height: buttonSize)
                        .contentShape(Capsule())
                        .glassEffect(.regular.interactive())

                        Spacer()

                        Button {
                            isSearchFocused = false
                            filterText = ""
                        } label: {
                            Image(systemName: "xmark")
                                .foregroundStyle(.black)
                                .font(.system(size: 20))
                                .frame(width: buttonSize, height: buttonSize)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                    }
                    .padding(.bottom)
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

// MARK: - FilteredSearchHistoryList

private struct FilteredSearchHistoryList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    let searchHistory: [SearchHistoryEntry]
    let pinnedSearches: [PinnedSearchEntry]
    let filterText: String
    @Binding var searchState: SearchState

    private var pinnedFilters: Set<[FilterQuery<FilterTerm>]> {
        Set(pinnedSearches.map(\.filters))
    }

    private let matcher = FuzzyMatcher(config: fuzzyMatchConfig)

    private var results: [SearchHistorySuggestion] {
        let trimmed = filterText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return searchHistory.map {
                SearchHistorySuggestion(
                    content: $0,
                    string: $0.filters.plaintext,
                    highlights: [],
                    rawScore: 1.0,
                    biasedScore: recencyBias(for: $0.lastUsedAt),
                )
            }
        }

        let candidates = searchHistory.map { ($0.filters.plaintext, $0) }
        // swiftlint:disable:next trailing_closure
        let entryByText = Dictionary(candidates, uniquingKeysWith: { first, _ in first })
        let query = matcher.prepare(trimmed)

        return matcher
            .matches(candidates.map { $0.0 }, against: trimmed)
            .compactMap { result in
                guard let entry = entryByText[result.candidate] else { return nil }
                return SearchHistorySuggestion(
                    content: entry,
                    string: result.candidate,
                    highlights: matcher.highlight(result.candidate, against: query) ?? [],
                    rawScore: result.match.score,
                    biasedScore: result.match.score * recencyBias(for: entry.lastUsedAt),
                )
            }
    }

    var body: some View {
        let pinnedFilters = pinnedFilters
        let results = results

        if results.isEmpty {
            ContentUnavailableView.search(text: filterText)
        } else {
            List {
                ForEach(results, id: \.content.id) { suggestion in
                    Button {
                        searchState.filters = suggestion.content.filters
                        searchState.performSearch()
                        dismiss()
                    } label: {
                        DebuggableScorableView(scorable: suggestion.biasedScore) {
                            HStack {
                                BoldedRangeText(
                                    text: suggestion.string,
                                    ranges: suggestion.highlights,
                                )
                                .padding(.vertical, 4)

                                Spacer()

                                if pinnedFilters.contains(suggestion.content.filters) {
                                    Image(systemName: "pin.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .tint(.primary)
                    .swipeActions(edge: .leading, allowsFullSwipe: true) {
                        if pinnedFilters.contains(suggestion.content.filters) {
                            Button {
                                historyAndPinnedStore.unpin(search: suggestion.content.filters)
                            } label: {
                                Label("Unpin", systemImage: "pin.slash")
                            }
                            .tint(.orange)
                        } else {
                            Button {
                                historyAndPinnedStore.pin(search: suggestion.content.filters)
                            } label: {
                                Label("Pin", systemImage: "pin")
                            }
                            .tint(.orange)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            historyAndPinnedStore.delete(search: suggestion.content.filters)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }
}

// MARK: - GroupedSearchHistoryList

private struct GroupedSearchHistoryList: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore

    let searchHistory: [SearchHistoryEntry]
    let pinnedSearches: [PinnedSearchEntry]
    @Binding var editMode: EditMode
    @Binding var selectedSearches: Set<Int64?>
    @Binding var searchState: SearchState

    private var isEditing: Bool {
        editMode == .active
    }

    private var pinnedFilters: Set<[FilterQuery<FilterTerm>]> {
        Set(pinnedSearches.map(\.filters))
    }

    private var groupedSearchHistory: [(TimeInterval, [SearchHistoryEntry])] {
        let calendar = Calendar.current
        let lastMidnight = calendar.startOfDay(for: Date())

        var boundaries: [(Date, TimeInterval)] = [
            (lastMidnight, .today),
            (calendar.date(byAdding: .day, value: -1, to: lastMidnight)!, .yesterday),
            (calendar.date(byAdding: .day, value: -7, to: lastMidnight)!, .pastWeek),
            (calendar.date(byAdding: .month, value: -1, to: lastMidnight)!, .pastMonth),
            (Date.distantPast, .older),
        ]

        var result: [(TimeInterval, [SearchHistoryEntry])] = []
        var currentEntries: [SearchHistoryEntry] = []

        for entry in searchHistory {
            while !boundaries.isEmpty && entry.lastUsedAt < boundaries.first!.0 {
                if !currentEntries.isEmpty {
                    result.append((boundaries.first!.1, currentEntries))
                    currentEntries = []
                }
                boundaries.removeFirst()
            }

            currentEntries.append(entry)
        }

        if !currentEntries.isEmpty {
            let interval = boundaries.isEmpty ? .older : boundaries[0].1
            result.append((interval, currentEntries))
        }

        return result
    }

    var body: some View {
        let pinnedFilters = pinnedFilters

        List(selection: $selectedSearches) {
            ForEach(groupedSearchHistory, id: \.0) { interval, entries in
                Section {
                    ForEach(entries, id: \.id) { entry in
                        Button {
                            guard !isEditing else { return }
                            searchState.filters = entry.filters
                            searchState.performSearch()
                            dismiss()
                        } label: {
                            HStack {
                                Text(entry.filters.plaintext)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .padding(.vertical, 4)

                                Spacer()

                                if pinnedFilters.contains(entry.filters) {
                                    Image(systemName: "pin.fill")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .tint(.primary)
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            if pinnedFilters.contains(entry.filters) {
                                Button {
                                    historyAndPinnedStore.unpin(search: entry.filters)
                                } label: {
                                    Label("Unpin", systemImage: "pin.slash")
                                }
                                .tint(.orange)
                            } else {
                                Button {
                                    historyAndPinnedStore.pin(search: entry.filters)
                                } label: {
                                    Label("Pin", systemImage: "pin")
                                }
                                .tint(.orange)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                historyAndPinnedStore.delete(search: entry.filters)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Text(interval.displayName)
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, $editMode)
    }
}
