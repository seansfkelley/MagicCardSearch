import SwiftUI
import SQLiteData

/// Wraps a preview in the same environment the app provides at startup,
/// providing a `Binding<SearchState>` for views that need it.
struct PreviewContainer<Content: View>: View {
    private let bookmarkedCardsStore: BookmarkedCardsStore
    private let historyAndPinnedStore: HistoryAndPinnedStore
    private let recentlyViewedCardsStore: RecentlyViewedCardsStore
    private let scryfallCatalogs: ScryfallCatalogs
    @State private var searchState: SearchState
    private let content: (Binding<SearchState>) -> Content

    init(@ViewBuilder content: @escaping (Binding<SearchState>) -> Content) {
        let database = try! appDatabase()
        prepareDependencies { $0.defaultDatabase = database }
        bookmarkedCardsStore = .init(database: database)
        let store = HistoryAndPinnedStore(database: database)
        historyAndPinnedStore = store
        recentlyViewedCardsStore = .init(database: database)
        scryfallCatalogs = .init()
        _searchState = State(initialValue: SearchState(
            historyAndPinnedStore: store,
            scryfallCatalogs: scryfallCatalogs
        ))
        self.content = content
    }

    var body: some View {
        content($searchState)
            .environment(bookmarkedCardsStore)
            .environment(historyAndPinnedStore)
            .environment(recentlyViewedCardsStore)
            .environment(scryfallCatalogs)
    }
}
