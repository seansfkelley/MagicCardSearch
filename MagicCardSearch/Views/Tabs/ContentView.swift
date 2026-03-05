import SwiftUI

enum Tab: String {
    case spoilers, bookmarks, random, search
}

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Tab = .search
    @State private var searchState: SearchState

    private var historyAndPinnedStore: HistoryAndPinnedStore
    private var scryfallCatalogs: ScryfallCatalogs

    init(historyAndPinnedStore: HistoryAndPinnedStore, scryfallCatalogs: ScryfallCatalogs) {
        self.historyAndPinnedStore = historyAndPinnedStore
        self.scryfallCatalogs = scryfallCatalogs
        _searchState = State(
            initialValue: SearchState(
                historyAndPinnedStore: historyAndPinnedStore,
                scryfallCatalogs: scryfallCatalogs,
            )
        )
    }

    var body: some View {
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
    }
}
