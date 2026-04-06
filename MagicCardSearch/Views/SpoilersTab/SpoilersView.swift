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

private let canonicalColorOrder = ["W", "U", "B", "R", "G", "C"]

struct SpoilersView: View {
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var orderedSelectableSets: [MTGSet] = []
    @State private var currentSearchResults: ScryfallObjectList<Card> = .empty()
    @State private var selectedColors: Set<String> = []

    @AppStorage("spoilersSelectedSetCode") private var selectedSetCode: SetCode = allSetsSentinel
    @AppStorage("spoilersSortOrder") private var sortOrder: SpoilersSortOrder = .spoiled
    @AppStorage("spoilersColorFilter") private var colorFilterStorage: String = ""

    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private static let client = ScryfallClient(logger: logger)

    private struct CacheKey: Hashable {
        let setCode: SetCode
        let sortOrder: SpoilersSortOrder
        let colorFilter: String
    }

    private static let objectListCache = StrongMemoryStorage<CacheKey, ScryfallObjectList<Card>>(
        config: .init(expiry: .hours(1), countLimit: 50)
    )

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    private let spacing: CGFloat = 4

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
                            systemImage: "sparkles",
                            description: Text("No new cards have been spoiled recently.")
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
                SpoilersFilterBarView(sortOrder: $sortOrder, selectedColors: $selectedColors)
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
                selectedColors = parseColorFilter(colorFilterStorage)
                recomputeSpoilingSets()
                reloadSpoilers()
            }
        }
        .onChange(of: scryfallCatalogs.catalogChangeNonce) {
            Self.objectListCache.removeAll()
            recomputeSpoilingSets()
            reloadSpoilers()
        }
        .onChange(of: selectedSetCode) {
            reloadSpoilers()
        }
        .onChange(of: sortOrder) {
            reloadSpoilers()
        }
        .onChange(of: selectedColors) {
            colorFilterStorage = serializeColorFilter(selectedColors)
            reloadSpoilers()
        }
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            NavigationStack {
                LazyPagingCardDetailNavigatorView(
                    list: currentSearchResults,
                    initialIndex: identifier.index,
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
                    .padding(.vertical, 8)

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
                            selectedCardIndex = index
                        }
                        .onAppear {
                            if index == results.data.count - 4 {
                                currentSearchResults.loadNextPage()
                            }
                        }
                        .padding(.horizontal, spacing / 2)
                    }

                    if (results.hasMore ?? false) || currentSearchResults.value.isLoadingNextPage {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                            .gridCellColumns(2)
                    }
                }
                .padding(.horizontal, spacing / 2)
                .padding(.vertical)
            }
        }
    }

    private func recomputeSpoilingSets() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now)!
        let newSets = scryfallCatalogs.sets?.values
            .filter {
                ($0.releasedAtAsDate ?? .distantPast) >= twoWeeksAgo &&
                $0.cardCount > 0 &&
                !ignoredSetTypes.contains($0.setType)
            }
            .sorted { $0.spoilerOrderingKey < $1.spoilerOrderingKey } ?? []

        orderedSelectableSets = newSets
        if selectedSetCode != allSetsSentinel && !newSets.contains(where: { SetCode($0.code) == selectedSetCode }) {
            selectedSetCode = allSetsSentinel
        }
    }

    private func reloadSpoilers() {
        guard !orderedSelectableSets.isEmpty else { return }

        let canonicalColorFilter = serializeColorFilter(selectedColors)
        let cacheKey = CacheKey(setCode: selectedSetCode, sortOrder: sortOrder, colorFilter: canonicalColorFilter)

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

        if let colorClause = buildColorClause(from: selectedColors) {
            queryParts.append(colorClause)
        }

        let query = queryParts.joined(separator: " ")

        let newObjectList = ScryfallObjectList<Card> { page in
            try await Self.client.searchCards(
                query: query,
                unique: .prints,
                order: sortOrder.scryfallSortMode,
                sortDirection: .desc,
                page: page,
            )
        }

        Self.objectListCache.setObject(newObjectList, forKey: cacheKey)
        currentSearchResults = newObjectList
        currentSearchResults.loadNextPage()
    }

    private func buildColorClause(from colors: Set<String>) -> String? {
        guard !colors.isEmpty else { return nil }

        let hasColorless = colors.contains("C")
        let chromatic = colors.subtracting(["C"])

        if !hasColorless {
            let colorString = canonicalColorOrder.filter { chromatic.contains($0) }.joined()
            return "color<=\(colorString)"
        } else if chromatic.isEmpty {
            return "color:C"
        } else {
            let colorString = canonicalColorOrder.filter { chromatic.contains($0) }.joined()
            return "(color:C OR color<=\(colorString))"
        }
    }

    private func serializeColorFilter(_ colors: Set<String>) -> String {
        canonicalColorOrder.filter { colors.contains($0) }.joined(separator: ",")
    }

    private func parseColorFilter(_ storage: String) -> Set<String> {
        Set(storage.split(separator: ",").map(String.init))
    }
}

private extension MTGSet {
    var spoilerOrderingKey: (Date, Int, String) {
        (
            releasedAtAsDate ?? .distantPast,
            parentSetCode == nil ? 0 : 1,
            name,
        )
    }
}
