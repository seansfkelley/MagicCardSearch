import SwiftUI
import SQLiteData
import OSLog

enum Tab: String {
    case spoilers, bookmarks, random, search
}

@main
struct MagicCardSearchApp: App {
    private var bookmarkedCardsStore: BookmarkedCardsStore
    private var historyAndPinnedStore: HistoryAndPinnedStore
    private var scryfallCatalogs: ScryfallCatalogs
    @State private var searchState: SearchState

    @AppStorage("selectedTab") private var selectedTab: Tab = .search

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
            TabView(selection: $selectedTab) {
                SwiftUI.Tab("Spoilers", systemImage: "sparkles", value: Tab.spoilers) {
                    SpoilersView(selectedTab: $selectedTab)
                }

                SwiftUI.Tab("Bookmarks", systemImage: "bookmark", value: Tab.bookmarks) {
                    BookmarksTabView(selectedTab: $selectedTab)
                }

                SwiftUI.Tab("Random", systemImage: "shuffle", value: Tab.random) {
                    RandomCardView()
                }

                SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: Tab.search) {
                    SearchTabView(searchState: $searchState)
                }
            }
            .environment(bookmarkedCardsStore)
            .environment(historyAndPinnedStore)
            .environment(scryfallCatalogs)
            .task {
                await scryfallCatalogs.hydrate()
            }
        }
    }
}
