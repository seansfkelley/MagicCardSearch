import ScryfallKit
import SwiftUI
import OSLog
import Cache
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "AllPrintsView")

struct AllPrintsView: View {
    struct CacheKey: Hashable, CustomStringConvertible {
        let oracleId: String
        let filterSettings: AllPrintsFilterSettings

        var description: String {
            "CacheKey(oracleId: \(oracleId), filterSettings: \(filterSettings))"
        }

        init(_ oracleId: String, _ filterSettings: AllPrintsFilterSettings) {
            self.oracleId = oracleId
            self.filterSettings = filterSettings
        }
    }

    // This was initially put in because of my inability to figure out proper request lifecycling,
    // but I eventually decided that it's probably a good idea regardless.
    //
    // The problem with lifecycling was that I cannot figure out how, for a view like this deeply
    // nested in the view hierarchy, how to ensure it only makes the request only if something
    // actually changed. I started trying task/onAppear/onFirstAppear and while each one was better
    // than the last, I still had issues where returning to the home screen would trigger the view
    // to be rebuilt (?!) and sometimes it would happen _again_ on reentry or for no discernible
    // reason. Sprinkling in Self._printChanges() indicated that the @identity of the view was
    // changing and presumably the culprit, but in most of those cases the parent views reported no
    // changes at all! So why did this one change identity? Something to do with being in a sheet?
    private static let objectListCache = StrongMemoryStorage<CacheKey, ScryfallObjectList<Card>>(
        config: .init(expiry: .seconds(60.0 * 60), countLimit: 20),
    )

    let oracleId: String
    let initialCardId: UUID

    @State private var objectList: ScryfallObjectList<Card> = .empty()
    // This is scene storage for the reasons outlined above -- we want to restore our position when
    // we re-foreground the app.
    @SceneStorage("allPrintsIndex") private var currentIndex: Int = 0
    @State private var showFilterPopover = false
    @State private var printFilterSettings = AllPrintsFilterSettings()

    @Environment(\.dismiss) private var dismiss
    @Environment(BookmarkedCardsStore.self) private var bookmarkedCardsStore
    @FetchAll private var bookmarks: [BookmarkedCard]

    // MARK: - Filter Settings

    private var scryfallSearchUrl: URL? {
        let baseURL = "https://scryfall.com/search"
        var components = URLComponents(string: baseURL)
        components?.queryItems = [
            URLQueryItem(name: "q", value: printFilterSettings.toQueryFor(oracleId: oracleId)),
            URLQueryItem(name: "order", value: "released"),
            URLQueryItem(name: "dir", value: "asc"),
        ]
        return components?.url
    }

    private var currentPrints: [Card] {
        objectList.value.latestValue?.data ?? []
    }

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < currentPrints.count else {
            return nil
        }
        return currentPrints[currentIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                if case .unloaded = objectList.value {
                    EmptyView()
                } else if let objectListData = objectList.value.latestValue {
                    let cards = objectListData.data
                    if cards.isEmpty {
                        if printFilterSettings.isDefault {
                            ContentUnavailableView(
                                "No Prints Found",
                                systemImage: "rectangle.on.rectangle.slash",
                                description: Text("This card doesn't have any printings?")
                            )
                        } else {
                            ContentUnavailableView {
                                Label("No Matching Prints", systemImage: "sparkle.magnifyingglass")
                            } description: {
                                Text("Widen your filters to see more results.")
                            } actions: {
                                Button {
                                    printFilterSettings.reset()
                                } label: {
                                    HStack {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Reset All Filters")
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.regular)
                            }
                        }
                    } else {
                        CoordinatedAllPrintsView(
                            cards: cards,
                            currentIndex: $currentIndex
                        )
                    }
                } else if let error = objectList.value.latestError {
                    ContentUnavailableView {
                        Label("Failed to load prints", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await reloadAllPrints()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if case .loading = objectList.value {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            ProgressView()
                                .tint(.white)
                            Text("Loading prints...")
                                .foregroundStyle(.white)
                                .font(.subheadline)
                            Spacer()
                        }
                        Spacer()
                    }
                    .background(Color(white: 0, opacity: 0.4))
                    .allowsHitTesting(false)
                }
            }
            // TODO: Should there be a title? It looks naked up there but a title is pretty useless.
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showFilterPopover.toggle()
                    } label: {
                        Image(systemName: printFilterSettings.isDefault
                            ? "line.3.horizontal.decrease.circle"
                            : "line.3.horizontal.decrease.circle.fill"
                        )
                    }
                    .popover(isPresented: $showFilterPopover) {
                        FilterPopoverView(filterSettings: $printFilterSettings)
                            .presentationCompactAdaptation(.popover)
                    }
                }

                if let currentCard, let bookmark = bookmarks.first(where: { $0.id == currentCard.id }) {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.unbookmark(id: bookmark.id)
                        } label: {
                            Image(systemName: "bookmark.fill")
                        }
                    }
                } else if let currentCard {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            bookmarkedCardsStore.bookmark(card: currentCard)
                        } label: {
                            Image(systemName: "bookmark")
                        }
                    }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {} label: {
                            Image(systemName: "bookmark")
                        }
                        .disabled(true)
                    }
                }

                if let url = scryfallSearchUrl {
                    ToolbarItem(placement: .topBarTrailing) {
                        ShareLink(item: url)
                    }
                }
            }
        }
        .onFirstAppear {
            Task {
                await reloadAllPrints()
            }
        }
        .onChange(of: printFilterSettings) {
            Task {
                await reloadAllPrints()
            }
        }
    }

    private func reloadAllPrints() async {
        let cacheKey = CacheKey(oracleId, printFilterSettings)

        if let cachedList = try? Self.objectListCache.entry(forKey: cacheKey) {
            logger.trace("hit cache for object list key=\(cacheKey)")
            objectList = cachedList.object
        } else {
            let searchQuery = printFilterSettings.toQueryFor(oracleId: oracleId)
            let client = ScryfallClient(logger: logger)
            objectList = ScryfallObjectList { page in
                try await client.searchCards(
                    query: searchQuery,
                    page: page,
                )
            }
            Self.objectListCache.setObject(objectList, forKey: cacheKey)
            logger.trace("set cache for object list key=\(cacheKey)")

            let targetCardId = if case .unloaded = objectList.value {
                initialCardId
            } else {
                currentPrints[safe: currentIndex]?.id
            }

            await objectList.loadAllRemainingPages().value

            if let targetCardId,
               let index = currentPrints.firstIndex(where: { $0.id == targetCardId }) {
                currentIndex = index
            } else if !currentPrints.isEmpty {
                currentIndex = 0
            }
        }
    }
}
