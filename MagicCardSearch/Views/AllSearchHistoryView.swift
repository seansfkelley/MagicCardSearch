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

struct AllSearchHistoryView: View {
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
            Group {
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
                    SearchBarLayout {
                        TextField("Filter searches...", text: $filterText)
                            .textFieldStyle(.plain)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                            .textContentType(.none)
                            .focused($isSearchFocused)

                        if !filterText.isEmpty {
                            Button {
                                filterText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(height: 44)
                    .contentShape(Capsule())
                    .glassEffect(.regular.interactive())
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

    private var results: [(entry: SearchHistoryEntry, match: HighlightedMatch<String>, score: Double)] {
        let trimmed = filterText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return [] }

        let candidates = searchHistory.map { ($0.filters.plaintext, $0) }
        let strings = candidates.map { $0.0 }
        let entryByText = Dictionary(candidates, uniquingKeysWith: { first, _ in first })

        return FuzzyMatcher(config: fuzzyMatchConfig)
            .matches(strings, against: trimmed)
            .compactMap { result -> (SearchHistoryEntry, HighlightedMatch<String>, Double)? in
                guard let entry = entryByText[result.candidate] else { return nil }
                return (entry, HighlightedMatch(value: result.candidate, string: result.candidate, query: trimmed), result.match.score)
            }
    }

    var body: some View {
        let pinnedFilters = pinnedFilters
        let results = results

        if results.isEmpty {
            ContentUnavailableView.search(text: filterText)
        } else {
            List {
                ForEach(results, id: \.entry.id) { entry, match, score in
                    var mutableMatch = match
                    Button {
                        searchState.filters = entry.filters
                        searchState.performSearch()
                        dismiss()
                    } label: {
                        DebuggableRowContentView(
                            suggestion: AutocompleteSuggestion(
                                source: .historyFilter(entry.lastUsedAt),
                                content: .filter(
                                    HighlightedMatch(
                                        value: FilterQuery<FilterTerm>.term(.name(.positive, false, entry.filters.plaintext)),
                                        string: entry.filters.plaintext,
                                        query: filterText
                                    )
                                ),
                                rawScore: score,
                                biasedScore: score
                            )
                        ) {
                            HStack {
                                HighlightedText(
                                    text: match.string,
                                    highlightRanges: mutableMatch.highlights
                                )
                                .padding(.vertical, 4)

                                Spacer()

                                if pinnedFilters.contains(entry.filters) {
                                    Image(systemName: "pin.fill")
                                        .foregroundStyle(.secondary)
                                }
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
