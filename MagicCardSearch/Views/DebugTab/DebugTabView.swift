import SwiftUI
import SQLiteData

#if DEBUG
struct DebugTabView: View {
    var scryfallCatalogs: ScryfallCatalogs
    @AppStorage("debugShowScores") private var showScores = true
    @Dependency(\.defaultDatabase) private var database

    var body: some View {
        List {
            Section("Autocomplete") {
                Toggle("Show Autocomplete Scores", isOn: $showScores)
            }
            Section("Caches") {
                DebugButton("Dump Search/Tag/Card Caches") {
                    if !CachingScryfallService.shared.dumpCaches() { throw DebugButtonError() }
                }
                DebugButton("Dump Catalog Caches") {
                    if !scryfallCatalogs.dumpCaches() { throw DebugButtonError() }
                }
            }
            Section("Database Tables") {
                DebugButton("Clear Recently Viewed Cards") {
                    try database.write { db in try RecentlyViewedCard.delete().execute(db) }
                }
                DebugButton("Clear Search History") {
                    try database.write { db in try SearchHistoryEntry.delete().execute(db) }
                }
                DebugButton("Clear Filter History") {
                    try database.write { db in try FilterHistoryEntry.delete().execute(db) }
                }
                DebugButton("Clear Pinned Searches") {
                    try database.write { db in try PinnedSearchEntry.delete().execute(db) }
                }
                DebugButton("Clear Pinned Filters") {
                    try database.write { db in try PinnedFilterEntry.delete().execute(db) }
                }
                DebugButton("Clear Bookmarks") {
                    try database.write { db in try BookmarkedCard.delete().execute(db) }
                }
            }
        }
        .navigationTitle("Debug")
    }
}

private struct DebugButtonError: Error {}

private struct DebugButton: View {
    let label: String
    let action: () throws -> Void
    @State private var result: Bool?

    init(_ label: String, action: @escaping () throws -> Void) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button {
            do {
                try action()
                withAnimation { result = true }
            } catch {
                withAnimation { result = false }
            }
            Task {
                try? await Task.sleep(for: .seconds(2))
                withAnimation { result = nil }
            }
        } label: {
            HStack {
                Text(label)
                Spacer()
                if let result {
                    Image(systemName: result ? "checkmark" : "xmark")
                        .foregroundStyle(.white)
                        .transition(.opacity)
                }
            }
        }
        .listRowBackground(
            ZStack {
                Color(uiColor: .secondarySystemGroupedBackground)
                Color.green.opacity(result == true ? 1 : 0)
                Color.red.opacity(result == false ? 1 : 0)
            }
            .animation(.default, value: result)
        )
    }
}

#Preview {
    List {
        DebugButton("Always Succeeds") {}
        DebugButton("Always Fails") { throw DebugButtonError() }
    }
}
#endif
