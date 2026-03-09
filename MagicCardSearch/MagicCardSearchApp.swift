import SwiftUI
import SQLiteData
import OSLog

@main
struct MagicCardSearchApp: App {
    private var bookmarkedCardsStore: BookmarkedCardsStore
    private var historyAndPinnedStore: HistoryAndPinnedStore
    private var recentlyViewedCardsStore: RecentlyViewedCardsStore
    private var scryfallCatalogs: ScryfallCatalogs

    init() {
        let database = try! appDatabase()

        prepareDependencies {
            $0.defaultDatabase = database
        }

        bookmarkedCardsStore = .init(database: database)
        historyAndPinnedStore = .init(database: database)
        recentlyViewedCardsStore = .init(database: database)
        scryfallCatalogs = .init(database: database)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(
                historyAndPinnedStore: historyAndPinnedStore,
                scryfallCatalogs: scryfallCatalogs
            )
            .environment(bookmarkedCardsStore)
            .environment(historyAndPinnedStore)
            .environment(recentlyViewedCardsStore)
            .environment(scryfallCatalogs)
            .task {
                await scryfallCatalogs.hydrate()
            }
        }
    }
}
