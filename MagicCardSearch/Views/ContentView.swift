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
                NavigationStack {
                    SpoilersView()
                }
            }

            SwiftUI.Tab("Bookmarks", systemImage: "bookmark", value: Tab.bookmarks) {
                NavigationStack {
                    BookmarkedCardListView()
                }
            }

            SwiftUI.Tab("Random", systemImage: "shuffle", value: Tab.random) {
                NavigationStack {
                    RandomCardView(advanceCard: $advanceRandomCard)
                }
            }

            SwiftUI.Tab("Search", systemImage: "magnifyingglass", value: Tab.search) {
                NavigationStack {
                    SearchTabView(searchState: $searchState, showSearchSheet: $showSearchSheet)
                }
            }
        }
        .onAppear {
            tabDelegate.onSearchTabTapped = { showSearchSheet = true }
            tabDelegate.onRandomTabTapped = { advanceRandomCard = true }
        }
        .introspect(.tabView, on: .iOS(.v26)) { tabBarController in
            // SwiftUI installs its own delegate, and if we clobber it without forwarding to it, we
            // break things like @AppStorage-backed tab restoration on background/foreground.
            guard tabBarController.delegate !== tabDelegate else { return }
            tabDelegate.forwardingDelegate = tabBarController.delegate
            tabBarController.delegate = tabDelegate
        }
    }
}

// MARK: - Search Tab Delegate

private final class TabBarDelegate: NSObject, UITabBarControllerDelegate {
    var onRandomTabTapped: (() -> Void)?
    var onSearchTabTapped: (() -> Void)?
    // nonisolated(unsafe): Claude claims that (1) these two methods are called by the Objective-C
    // runtime, (2) these calls do not go through Swift's actor system, and (3) the calls _are_
    // always on the main thread. Assuming this is correct, the problem is only that the Swift
    // compiler cannot reason about safety and not that this is incorrect.
    nonisolated(unsafe) weak var forwardingDelegate: (any UITabBarControllerDelegate)?

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
                return false
            case 3:
                onSearchTabTapped?()
                return false
            default:
                break
            }
        }
        return forwardingDelegate?.tabBarController?(tabBarController, shouldSelect: viewController) ?? true
    }

    // Clause wrote this method. I don't know anything about Objective-C dynamic dispatch but it works.
    override func responds(to aSelector: Selector!) -> Bool {
        super.responds(to: aSelector) || forwardingDelegate?.responds(to: aSelector) == true
    }

    // Clause wrote this method. I don't know anything about Objective-C dynamic dispatch but it works.
    override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if !super.responds(to: aSelector), let forwardingDelegate, forwardingDelegate.responds(to: aSelector) {
            return forwardingDelegate
        }
        return super.forwardingTarget(for: aSelector)
    }
}
