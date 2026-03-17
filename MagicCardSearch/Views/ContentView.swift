import SwiftUI
import SwiftUIIntrospect

enum Tab: String {
    case spoilers, bookmarks, random, search
}

struct ContentView: View {
    @AppStorage("selectedTab") private var selectedTab: Tab = .search
    @State private var searchState: SearchState
    @State private var showSearchSheet = false
    @State private var advanceRandomCard = false

    // UITabBarController.delegate is weak, so we retain it here.
    private let tabDelegate: TabBarDelegate

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
        tabDelegate = TabBarDelegate()
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Spoilers", systemImage: "sparkles", value: Tab.spoilers) {
                SpoilersView()
            }

            SwiftUI.Tab("Bookmarks", systemImage: "bookmark", value: Tab.bookmarks) {
                BookmarkedCardListView()
            }

            SwiftUI.Tab("Random", systemImage: "shuffle", value: Tab.random) {
                RandomCardView(advanceCard: $advanceRandomCard)
            }

            SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: Tab.search) {
                SearchTabView(searchState: $searchState, showSearchSheet: $showSearchSheet)
            }
        }
        .onAppear {
            tabDelegate.onSearchTabTapped = { showSearchSheet = true }
            tabDelegate.onRandomTabTapped = { advanceRandomCard = true }
        }
        .introspect(.tabView, on: .iOS(.v26)) { tabBarController in
            tabBarController.delegate = tabDelegate
        }
    }
}

// MARK: - Search Tab Delegate

private final class TabBarDelegate: NSObject, UITabBarControllerDelegate {
    var onRandomTabTapped: (() -> Void)?
    var onSearchTabTapped: (() -> Void)?

    func tabBarController(
        _ tabBarController: UITabBarController,
        shouldSelect viewController: UIViewController
    ) -> Bool {
        if tabBarController.selectedViewController === viewController {
            // AFAICT there is no foolproof way to enforce the render order and underlying tab value
            // agree or are convertible to each other, so don't even suggest we can do it, just do
            // the jank thing that will break more obviously.
            switch tabBarController.selectedIndex {
            case 2:
                onRandomTabTapped?()
            case 3:
                onSearchTabTapped?()
            default:
                break
            }
        }
        return true
    }
}
