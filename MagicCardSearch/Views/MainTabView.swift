import SwiftUI

enum Tab: String {
    case spoilers
    case bookmarks
    case random
    case search
}

struct MainTabView: View {
    @Binding var searchState: SearchState

    @AppStorage("selectedTab") private var selectedTab: Tab = .spoilers

    var body: some View {
        TabView(selection: $selectedTab) {
            SwiftUI.Tab("Spoilers", systemImage: "sparkles", value: Tab.spoilers) {
                SpoilersView(searchState: $searchState, selectedTab: $selectedTab)
            }

            SwiftUI.Tab("Bookmarks", systemImage: "bookmark", value: Tab.bookmarks) {
                BookmarksTabView(searchState: $searchState, selectedTab: $selectedTab)
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
