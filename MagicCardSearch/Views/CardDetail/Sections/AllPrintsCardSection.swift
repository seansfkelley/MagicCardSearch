import ScryfallKit
import SwiftUI
import SQLiteData
import NukeUI
import OSLog
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "CardAllPrintsView")

struct AllPrintsCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let oracleId: String
    let currentCardId: UUID

    @State private var showingPrintsSheet = false

    var body: some View {
        Button {
            showingPrintsSheet = true
        } label: {
            HStack {
                Label {
                    Text("All Prints")
                } icon: {
                    Image(systemName: "rectangle.stack")
                        .rotationEffect(.degrees(90))
                }
                .labelReservedIconWidth(iconWidth)
                .font(.headline)
                // pixel-push to make it line up with the adjacent DisclosureGroup
                .padding(.vertical, 3)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14)) // determinted empirically to match DisclosureGroup
                    .foregroundStyle(.primary)
                    .fontWeight(.semibold)
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingPrintsSheet) {
            AllPrintsDetailView(oracleId: oracleId, initialCardId: currentCardId)
        }
    }
}

// MARK: - Card All Prints View

private struct AllPrintsDetailView: View {
    private struct CacheKey: Hashable, CustomStringConvertible {
        let oracleId: String
        let filterSettings: PrintFilterSettings

        var description: String {
            "CacheKey(oracleId: \(oracleId), filterSettings: \(filterSettings))"
        }

        init(_ oracleId: String, _ filterSettings: PrintFilterSettings) {
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
    @State private var printFilterSettings = PrintFilterSettings()

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
                        CardPrintsDetailView(
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

// MARK: - Card Prints Detail View

private struct CardPrintsDetailView: View {
    let cards: [Card]
    @Binding var currentIndex: Int

    // It seems that these cannot share a position object, so we bridge between the two and,
    // unfortunately, also the currentIndex binding from the parent.
    @State private var mainScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var thumbnailScrollPosition = ScrollPosition(idType: UUID.self)
    @State private var partialScrollOffsetFraction: CGFloat = 0
    @State private var isFlipped: Bool = false

    private var currentCard: Card? {
        guard currentIndex >= 0 && currentIndex < cards.count else { return nil }
        return cards[currentIndex]
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                PagingCardImageView(
                    cards: cards,
                    scrollPosition: $mainScrollPosition,
                    partialScrollOffsetFraction: $partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: $isFlipped
                )

                ThumbnailPreviewStrip(
                    cards: cards,
                    scrollPosition: $thumbnailScrollPosition,
                    partialScrollOffsetFraction: partialScrollOffsetFraction,
                    screenWidth: geometry.size.width,
                    isFlipped: isFlipped
                )

                Spacer()

                Text("\(currentIndex + 1) of \(cards.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear {
            if let currentCard {
                mainScrollPosition.scrollTo(id: currentCard.id)
                thumbnailScrollPosition.scrollTo(id: currentCard.id)
            }
        }
        .onChange(of: currentIndex) { _, newIndex in
            if let cardId = cards[safe: newIndex]?.id {
                if mainScrollPosition.viewID(type: UUID.self) != cardId {
                    mainScrollPosition.scrollTo(id: cardId)
                }
                if thumbnailScrollPosition.viewID(type: UUID.self) != cardId {
                    thumbnailScrollPosition.scrollTo(id: cardId)
                }
            }
        }
        .onChange(of: mainScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated because the calculated partial scroll offset thing makes sure
                // that the thumbnails are moving proportionally to the main view.
                if thumbnailScrollPosition.viewID(type: UUID.self) != newCardId {
                    thumbnailScrollPosition.scrollTo(id: newCardId)
                }
            }
        }
        .onChange(of: thumbnailScrollPosition.viewID(type: UUID.self)) { _, newCardId in
            if let newCardId, let newIndex = cards.firstIndex(where: { $0.id == newCardId }), newIndex != currentIndex {
                currentIndex = newIndex
                // n.b. not animated to prevent excessive motion and potential image loads.
                if mainScrollPosition.viewID(type: UUID.self) != newCardId {
                    mainScrollPosition.scrollTo(id: newCardId)
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}

// MARK: - Paging Card Image View

private struct PagingCardImageView: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    @Binding var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    @Binding var isFlipped: Bool

    @State private var scrollPhase: ScrollPhase = .idle

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(cards, id: \.id) { card in
                    VStack(spacing: 0) {
                        CardView(
                            card: card,
                            quality: .large,
                            isFlipped: $isFlipped,
                            cornerRadius: 16,
                            enableZoomGestures: true,
                        )
                        .padding(.horizontal)

                        SetMetadataCardSection(
                            setCode: card.set,
                            setName: card.setName,
                            collectorNumber: card.collectorNumber,
                            rarity: card.rarity,
                            lang: card.lang,
                            releasedAtAsDate: card.releasedAtAsDate,
                        )
                        .padding(.horizontal)
                        .padding(.vertical)
                    }
                    .frame(width: screenWidth)
                    .id(card.id)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(
            for: CGFloat.self,
            of: { geometry in
                guard let currentId = scrollPosition.viewID(type: UUID.self),
                      let currentIdx = cards.firstIndex(where: { $0.id == currentId }) else {
                    return 0
                }
                return (CGFloat(currentIdx) * geometry.containerSize.width - geometry.contentOffset.x) / geometry.containerSize.width
            },
            action: { _, new in
                partialScrollOffsetFraction = new
            })
    }
}

// MARK: - Thumbnail Preview Strip

private struct ThumbnailPreviewStrip: View {
    let cards: [Card]
    @Binding var scrollPosition: ScrollPosition
    var partialScrollOffsetFraction: CGFloat
    let screenWidth: CGFloat
    var isFlipped: Bool

    private let thumbnailHeight: CGFloat = 100
    private let thumbnailSpacing: CGFloat = 8

    private var thumbnailWidth: CGFloat {
        thumbnailHeight * Card.aspectRatio
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: thumbnailSpacing) {
                ForEach(cards, id: \.id) { card in
                    CardView(
                        card: card,
                        quality: .small,
                        isFlipped: .constant(isFlipped),
                        cornerRadius: 4,
                        showFlipButton: false
                    )
                    .scaleEffect(card.id == scrollPosition.viewID(type: UUID.self) ? 1.1 : 1.0)
                    // TODO: Enable this but only for the scale effect -- as written, it seems to animate the
                    // padding or otherwise cause whacko UI jitters.
                    // .animation(.easeOut(duration: 0.075), value: card.id == scrollPosition.viewID(type: UUID.self))
                    //
                    // Setting width here is crucial for the initial positioning; before the
                    // images have loaded, the LazyHStack doesn't know where to scroll to in
                    // order to show the initially-selected card. This should also help with
                    // pop-in of images on slow connections.
                    .frame(width: thumbnailWidth, height: thumbnailHeight)
                    .id(card.id)
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            scrollPosition.scrollTo(id: card.id)
                        }
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.leading, partialScrollOffsetFraction * (thumbnailWidth + thumbnailSpacing))
            .padding(.vertical, 12)
        }
        .contentMargins(.horizontal, (screenWidth - thumbnailWidth) / 2, for: .scrollContent)
        .scrollPosition($scrollPosition, anchor: .center)
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .background(Color.clear)
        .frame(height: thumbnailHeight + 16)
    }
}

private struct PrintFilterSettings: Equatable, Hashable, CustomStringConvertible {
    enum FrameFilter: String, CaseIterable {
        case any = "Any"
        case retro = "Retro"
        case modern = "Modern"
    }

    enum TextFilter: String, CaseIterable {
        case any = "Any"
        case normal = "Normal"
        case fullArt = "Full-art"
    }

    enum GameFilter: String, CaseIterable {
        case any = "Any"
        case digital = "Digital"
        case paper = "Paper"
    }

    var frame: FrameFilter = .any
    var text: TextFilter = .any
    var game: GameFilter = .any

    var isDefault: Bool {
        frame == .any && text == .any && game == .any
    }

    mutating func reset() {
        frame = .any
        text = .any
        game = .any
    }

    var description: String {
        "PrintFilterSettings(frame: .\(frame), text: .\(text), game: .\(game))"
    }

    func toQueryFor(oracleId: String) -> String {
        var query = "oracleid:\(oracleId) include:extras unique:prints order:released dir:desc"

        switch frame {
        case .any:
            break
        case .retro:
            query += " frame:old"
        case .modern:
            query += " frame:new"
        }

        switch text {
        case .any:
            break
        case .normal:
            query += " -is:full"
        case .fullArt:
            query += " is:full"
        }

        switch game {
        case .any:
            break
        case .digital:
            query += " (game:mtgo OR game:arena)"
        case .paper:
            query += " game:paper"
        }

        return query
    }
}

private struct FilterPopoverView: View {
    @Binding var filterSettings: PrintFilterSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Section("Frame") {
                Picker("Frame", selection: $filterSettings.frame) {
                    ForEach(PrintFilterSettings.FrameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Text") {
                Picker("Text", selection: $filterSettings.text) {
                    ForEach(PrintFilterSettings.TextFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section("Game") {
                Picker("Game", selection: $filterSettings.game) {
                    ForEach(PrintFilterSettings.GameFilter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
            }

            Button {
                filterSettings.reset()
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Show All Prints")
                }
                .frame(maxWidth: .infinity)
                .foregroundStyle(filterSettings.isDefault ? .gray : .red)
            }
            .buttonStyle(.borderless)
            .disabled(filterSettings.isDefault)
            .padding(.top)
        }
        .padding(20)
        .frame(width: 320)
        .glassEffect(.clear, in: .rect(cornerRadius: 16))
    }
}
