import SwiftUI
import SQLiteData

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
        let grouped = Dictionary(grouping: searchHistory) { entry in
            timeInterval(for: entry.lastUsedAt)
        }
        
        return TimeInterval.allCases.compactMap { interval in
            guard let entries = grouped[interval], !entries.isEmpty else { return nil }
            return (interval, entries)
        }
    }
    
    private func timeInterval(for date: Date) -> TimeInterval {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInYesterday(date) {
            return .yesterday
        } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                  date > weekAgo {
            return .pastWeek
        } else if let monthAgo = calendar.date(byAdding: .month, value: -1, to: now),
                  date > monthAgo {
            return .pastMonth
        } else {
            return .older
        }
    }
    
    enum TimeInterval: CaseIterable {
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
