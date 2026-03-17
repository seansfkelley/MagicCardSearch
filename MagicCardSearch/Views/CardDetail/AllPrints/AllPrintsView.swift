import ScryfallKit
import SwiftUI
import OSLog
import Cache
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "AllPrintsView")

struct AllPrintsView: View {
    struct CacheKey: Hashable, CustomStringConvertible {
        let oracleId: String
        let fetchKey: AllPrintsFilterSettings.FetchKey

        var description: String {
            "CacheKey(oracleId: \(oracleId), fetchKey: \(fetchKey))"
        }

        init(_ oracleId: String, _ settings: AllPrintsFilterSettings) {
            self.oracleId = oracleId
            self.fetchKey = settings.fetchKey
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
    @State private var sortedCards: LoadableResult<[Card], SearchErrorState> = .unloaded
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

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < (objectList.value.latestValue?.data.count ?? -1) else {
            return nil
        }
        return objectList.value.latestValue?.data[currentIndex]
    }

    var body: some View {
        NavigationStack {
            Group {
                switch sortedCards {
                case .unloaded, .loading:
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
                case .loaded(let cards, _):
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
                case .errored(_, let error):
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
        .onChange(of: printFilterSettings) { oldSettings, newSettings in
            if oldSettings.fetchKey == newSettings.fetchKey {
                resortResults(andScrollTo: currentCard?.id)
            } else {
                Task {
                    await reloadAllPrints()
                }
            }
        }
    }

    // This is basically just a committed computed property. We commit it because it's expensive to
    // calculate. Relatively. And maybe to prevent jitters.
    private func resortResults(andScrollTo targetCardId: UUID?) {
        switch sortedCards {
        case .unloaded:
            print("before: unloaded")
        case .loading(let t, let e):
            print("before: loading")
        case .loaded(let t, let e):
            print("before: loaded")
        case .errored(let t, let e):
            print("before: errored")
        }

        sortedCards = objectList.value.map(value: { printFilterSettings.sort($0.data) })
        if let targetCardId,
           let index = sortedCards.latestValue?.firstIndex(where: { $0.id == targetCardId }) {
            currentIndex = index
        } else if !(sortedCards.latestValue ?? []).isEmpty {
            currentIndex = 0
        }

        switch sortedCards {
        case .unloaded:
            print("after: unloaded")
        case .loading(let t, let e):
            print("after: loading")
        case .loaded(let t, let e):
            print("after: loaded")
        case .errored(let t, let e):
            print("after: errored")
        }
    }

    private func reloadAllPrints() async {
        let cacheKey = CacheKey(oracleId, printFilterSettings)

        if let cachedList = try? Self.objectListCache.entry(forKey: cacheKey) {
            logger.trace("hit cache for object list key=\(cacheKey)")
            objectList = cachedList.object
            resortResults(andScrollTo: currentCard?.id)
        } else {
            let searchQuery = printFilterSettings.toQueryFor(oracleId: oracleId)
            let client = ScryfallClient(logger: logger)
            let currentObjectList = ScryfallObjectList { page in
                try await client.searchCards(
                    query: searchQuery,
                    page: page,
                )
            }
            Self.objectListCache.setObject(currentObjectList, forKey: cacheKey)
            logger.trace("set cache for object list key=\(cacheKey)")

            let targetCardId = if case .unloaded = currentObjectList.value {
                initialCardId
            } else {
                sortedCards.latestValue?[safe: currentIndex]?.id
            }

            objectList = currentObjectList
            sortedCards = .unloaded

            await currentObjectList.loadAllRemainingPages().value
            // Kinda jank. Never hit this branch either, to my knowledge.
            guard objectList === currentObjectList else { return }

            resortResults(andScrollTo: targetCardId)
        }
    }
}
