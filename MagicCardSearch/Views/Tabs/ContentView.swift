import SwiftUI
import SwiftUIIntrospect

enum Tab: String {
    case spoilers, bookmarks, random, search
}

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Tab = .search
    @State private var searchState: SearchState
    @State private var showSearchSheet = false

    // UITabBarController.delegate is weak, so we retain it here.
    private let tabDelegate: SearchTabDelegate

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
        tabDelegate = SearchTabDelegate()
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
                SearchTabView(searchState: $searchState, showSearchSheet: $showSearchSheet)
            }
        }
        .onAppear {
            tabDelegate.onSearchTabTapped = { showSearchSheet = true }
        }
        .introspect(.tabView, on: .iOS(.v26)) { tabBarController in
            tabBarController.delegate = tabDelegate
        }
    }
}

// MARK: - Search Tab Delegate

private final class SearchTabDelegate: NSObject, UITabBarControllerDelegate {
    var onSearchTabTapped: (() -> Void)?

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if tabBarController.selectedViewController === viewController,
           tabBarController.selectedIndex == 3 {
            onSearchTabTapped?()
        }
        return true
    }
}
