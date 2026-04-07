import SwiftUI
import ScryfallKit
import OSLog
import Cache

// Exists because apparently @AppStorage cannot deal with nil, which is pretty amateur-level shit.
let allSetsSentinel = SetCode("sentinel")

private let ignoredSetTypes: Set<MTGSet.Kind> = [
    .token,
]

private let logger = Logger(subsystem: "MagicCardSearch", category: "SpoilersView")

struct SpoilersView: View {
    private struct CacheKey: Hashable {
        let setCode: SetCode
        let sortOrder: SpoilersSortOrder
        let colors: Set<Card.Color>
        let showUniquePrints: Bool
    }

    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var orderedSelectableSets: [MTGSet] = []
    @State private var currentSearchResults: ScryfallObjectList<Card> = .empty()
    @State private var selectedCardIndex: IdentifiableInt?

    @AppStorage("spoilersSelectedSetCode") private var selectedSetCode: SetCode = allSetsSentinel
    @AppStorage("spoilersSortOrder") private var sortOrder: SpoilersSortOrder = .spoiled
    @AppStorage("spoilersColorFilter") private var selectedColors: Set<Card.Color> = []
    @AppStorage("spoilersShowUniquePrints") private var showUniquePrints: Bool = true

    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private var currentCacheKey: CacheKey {
        .init(setCode: selectedSetCode, sortOrder: sortOrder, colors: selectedColors, showUniquePrints: showUniquePrints)
    }

    let cardSearchService: CardSearchService

    private static let objectListCache = StrongMemoryStorage<CacheKey, ScryfallObjectList<Card>>(
        config: .init(expiry: .hours(1), countLimit: 50)
    )

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    private let spacing: CGFloat = 4

    init(cardSearchService: CardSearchService? = nil) {
        self.cardSearchService = cardSearchService ?? CachingScryfallService.shared
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            if orderedSelectableSets.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                switch currentSearchResults.value {
                case .loading(nil, _), .unloaded:
                    ProgressView()
                        .scaleEffect(1.5)

                case .errored(nil, let error):
                    ContentUnavailableView(
                        "Unable to Load Spoilers",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error.description)
                    )

                case .loading(let results?, _), .loaded(let results, _), .errored(let results?, _):
                    if results.data.isEmpty {
                        ContentUnavailableView(
                            "No Spoilers",
                            systemImage: "rectangle.portrait.slash",
                            description: Text("No recent spoilers matching your filters.")
                        )
                    } else {
                        spoilersGrid(results: results)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                SpoilersSetSelectorView(spoilingSets: orderedSelectableSets, selectedSetCode: $selectedSetCode)
                Divider()
                SpoilersFilterBarView(sortOrder: $sortOrder, selectedColors: $selectedColors, showUniquePrints: $showUniquePrints)
            }
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 20))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if isRunningTests() {
                logger.info("skipping spoilers load in test environment")
            } else {
                recomputeSpoilingSets()
                loadFilteredSpoilers()
            }
        }
        .onChange(of: scryfallCatalogs.catalogChangeNonce) {
            recomputeSpoilingSets()
        }
        .onChange(of: currentCacheKey) {
            loadFilteredSpoilers()
        }
        .sheet(item: $selectedCardIndex) { index in
            NavigationStack {
                LazyPagingCardDetailNavigatorView(
                    list: currentSearchResults,
                    initialIndex: index.value,
                    cardFlipStates: $cardFlipStates,
                    searchState: nil,
                )
            }
        }
    }

    @ViewBuilder
    private func spoilersGrid(results: ObjectList<Card>) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Text("^[\(results.totalCards ?? 0) spoiler](inflect: true)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom)

                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(results.data.enumerated()), id: \.element.id) { index, card in
                        CardView(
                            card: card,
                            quality: .normal,
                            isFlipped: $cardFlipStates.for(card.id),
                            cornerRadius: 10,
                            enableCopyActions: true,
                            enableZoomGestures: .pinchOnly,
                            zoomGestureBasisAdjustment: 3.0,
                        )
                        .onTapGesture {
                            selectedCardIndex = .init(index)
                        }
                        .onAppear {
                            if index == results.data.count - 4 {
                                currentSearchResults.loadNextPage()
                            }
                        }
                        .padding(.horizontal, spacing / 2)
                        .overlay(alignment: .bottom) {
                            if let previewedAt = card.preview?.previewedAt, let date = PlainDate(from: previewedAt) {
                                Text(date.relativeLabel)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                                    .padding(6)
                            }
                        }
                    }
                }

                if (results.hasMore ?? false) || currentSearchResults.value.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    Text("Fin.")
                        .fontDesign(.serif)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top)
                }
            }
            .padding(.horizontal, spacing / 2)
            .padding(.vertical)
        }
    }

    private func recomputeSpoilingSets() {
        // Exploit ISO8601-style date formats to avoid ever having to parse the date.
        let recencyCutoff = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now)?
            .ISO8601Format(.iso8601.year().month().day().dateSeparator(.dash)) ?? "1900-01-01"

        let newSets = scryfallCatalogs.sets?.values
            .filter {
                ($0.releasedAt ?? "1900-01-01") >= recencyCutoff &&
                $0.cardCount > 0 &&
                !ignoredSetTypes.contains($0.setType)
            }
            .sorted { $0.spoilerSortKey < $1.spoilerSortKey } ?? []

        orderedSelectableSets = newSets
        if selectedSetCode != allSetsSentinel && !newSets.contains(where: { SetCode($0.code) == selectedSetCode }) {
            selectedSetCode = allSetsSentinel
        }
    }

    private func loadFilteredSpoilers() {
        guard !orderedSelectableSets.isEmpty else { return }

        let cacheKey = currentCacheKey

        if let cached = try? Self.objectListCache.entry(forKey: cacheKey) {
            currentSearchResults = cached.object
            return
        }

        var queryParts: [String] = []

        if selectedSetCode == allSetsSentinel {
            queryParts.append("date>=today")
        } else {
            queryParts.append("set:\(selectedSetCode.rawValue.lowercased())")
        }

        if !selectedColors.isEmpty {
            let orClauses = selectedColors.map { "color:\($0.rawValue.lowercased())" }.joined(separator: " OR ")
            queryParts.append("(\(orClauses))")

            let nonColorless = selectedColors.subtracting([.C])
            if !nonColorless.isEmpty {
                queryParts.append("color<=\(nonColorless.map { $0.rawValue.lowercased() }.joined())")
            }
        }

        let query = queryParts.joined(separator: " ")

        let newObjectList = ScryfallObjectList<Card> { @MainActor [cardSearchService] page in
            try await cardSearchService.searchCards(
                query: query,
                unique: showUniquePrints ? .prints : .cards,
                order: sortOrder.scryfallSortMode,
                sortDirection: .desc,
                page: page,
            )
        }

        Self.objectListCache.setObject(newObjectList, forKey: cacheKey)
        currentSearchResults = newObjectList
        currentSearchResults.loadNextPage()
    }
}

private extension PlainDate {
    var relativeLabel: String {
        switch distance(to: .now) {
        case -1: "tomorrow"
        case 0: "today"
        case 1: "yesterday"
        case let days: days < 0 ? "in \(days) days" : "\(days) days ago"
        }
    }
}

private extension MTGSet {
    var spoilerSortKey: (Date, Int, String) {
        (
            releasedAtAsDate ?? .distantPast,
            parentSetCode == nil ? 0 : 1,
            name,
        )
    }
}
