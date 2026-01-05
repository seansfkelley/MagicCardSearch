import SwiftUI
import SQLiteData

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

struct AllSearchHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(HistoryAndPinnedStore.self) private var historyAndPinnedStore
    
    @FetchAll(SearchHistoryEntry.order { $0.lastUsedAt.desc() })
    var searchHistory
    
    @State private var editMode: EditMode = .inactive
    @State private var selectedSearches: Set<Int64?> = []

    private var isEditing: Bool {
        return editMode == .active
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
        NavigationStack {
            Group {
                if searchHistory.isEmpty {
                    ContentUnavailableView(
                        "No Recent Searches",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Your search history will appear here.")
                    )
                } else {
                    List(selection: $selectedSearches) {
                        ForEach(groupedSearchHistory, id: \.0) { interval, entries in
                            Section {
                                ForEach(entries, id: \.id) { entry in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.filters.map { $0.description }.joined(separator: " "))
                                            .font(.body)
                                            .foregroundStyle(.primary)
                                            .lineLimit(3)
                                    }
                                    .padding(.vertical, 4)
                                    .contentShape(Rectangle())
                                    .tag(entry.id!)
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            historyAndPinnedStore.delete(search: entry.id)
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
            .navigationTitle("Search History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
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
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            withAnimation {
                                historyAndPinnedStore.delete(searches: selectedSearches)
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
                        .disabled(searchHistory.isEmpty)
                    }
                }
            }
        }
    }
}
