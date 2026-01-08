import SwiftUI
import SQLiteData
import OSLog

@main
struct MagicCardSearchApp: App {
    private var bookmarkedCardsStore: BookmarkedCardsStore
    private var historyAndPinnedStore: HistoryAndPinnedStore
    private var scryfallCatalogs: ScryfallCatalogs
    @State private var searchState: SearchState

    init() {
        let database = try! appDatabase()

        prepareDependencies {
            $0.defaultDatabase = database
        }

        bookmarkedCardsStore = .init(database: database)
        historyAndPinnedStore = .init(database: database)
        scryfallCatalogs = .init(database: database)
        _searchState = State(
            initialValue: SearchState(
                historyAndPinnedStore: historyAndPinnedStore,
                scryfallCatalogs: scryfallCatalogs,
            )
        )
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(searchState: $searchState)
                .environment(bookmarkedCardsStore)
                .environment(historyAndPinnedStore)
                .environment(scryfallCatalogs)
                .task {
                    await scryfallCatalogs.hydrate()
                }
        }
    }
}
