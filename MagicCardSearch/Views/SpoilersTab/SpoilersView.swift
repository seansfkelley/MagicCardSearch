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
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var orderedSelectableSets: [MTGSet] = []
    @State private var currentSearchResults: ScryfallObjectList<Card> = .empty()

    @AppStorage("spoilersSelectedSetCode") private var selectedSetCode: SetCode = allSetsSentinel

    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private static let client = ScryfallClient(logger: logger)

    private static let objectListCache = StrongMemoryStorage<SetCode, ScryfallObjectList<Card>>(
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
            SpoilersSetSelectorView(spoilingSets: orderedSelectableSets, selectedSetCode: $selectedSetCode)
                .padding(.horizontal, 8)
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if isRunningTests() {
                logger.info("skipping spoilers load in test environment")
            } else {
                recomputeSpoilingSets()
                reloadSpoilers()
            }
        }
        .onChange(of: scryfallCatalogs.catalogChangeNonce) {
            recomputeSpoilingSets()
        }
        .onChange(of: selectedSetCode) {
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

        if let cached = try? Self.objectListCache.entry(forKey: selectedSetCode) {
            currentSearchResults = cached.object
            return
        }

        let query: String
        if selectedSetCode == allSetsSentinel {
            query = "date>=today"
        } else {
            query = "set:\(selectedSetCode.rawValue.lowercased())"
        }

        let newObjectList = ScryfallObjectList<Card> { page in
            try await Self.client.searchCards(
                query: query,
                unique: .prints,
                order: .spoiled,
                sortDirection: .desc,
                page: page,
            )
        }

        Self.objectListCache.setObject(newObjectList, forKey: selectedSetCode)
        currentSearchResults = newObjectList
        currentSearchResults.loadNextPage()
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
