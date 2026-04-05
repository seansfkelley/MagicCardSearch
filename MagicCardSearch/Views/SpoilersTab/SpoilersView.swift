import SwiftUI
import ScryfallKit
import OSLog
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "SpoilersView")

struct SpoilersView: View {
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]
    @State private var spoilingSets: [MTGSet] = []
    @State private var objectList: ScryfallObjectList<Card> = .empty()

    @AppStorage("spoilersSelectedSetCode") private var selectedSetCode: String = ""

    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    private static let objectListCache = StrongMemoryStorage<String, ScryfallObjectList<Card>>(
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

            if spoilingSets.isEmpty {
                ProgressView()
                    .scaleEffect(1.5)
            } else {
                switch objectList.value {
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
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if isRunningTests() {
                logger.info("skipping spoilers load in test environment")
            } else {
                recomputeSpoilingSets()
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
                    list: objectList,
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
                            objectList.loadNextPage()
                        }
                    }
                    .padding(.horizontal, spacing / 2)
                }

                if (results.hasMore ?? false) || objectList.value.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .gridCellColumns(2)
                }
            }
            .padding(.horizontal, spacing / 2)
            .padding(.vertical)
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                SpoilersSetSelectorView(spoilingSets: spoilingSets, selectedSetCode: $selectedSetCode)
                Divider()
            }
            .background(Color(uiColor: .systemBackground))
        }
    }

    private func recomputeSpoilingSets() {
        let twoWeeksAgo = Calendar.current.date(byAdding: .weekOfYear, value: -2, to: .now)!
        let newSets = scryfallCatalogs.sets?.values
            .filter { ($0.releasedAtAsDate ?? .distantPast) >= twoWeeksAgo }
            .sorted { ($0.releasedAtAsDate ?? .distantPast) > ($1.releasedAtAsDate ?? .distantPast) } ?? []

        if !selectedSetCode.isEmpty && !newSets.contains(where: { $0.code == selectedSetCode }) {
            selectedSetCode = ""
        }

        if newSets.map(\.code) != spoilingSets.map(\.code) {
            Self.objectListCache.removeAll()
        }

        spoilingSets = newSets
        reloadSpoilers()
    }

    private func reloadSpoilers() {
        guard !spoilingSets.isEmpty else { return }

        if let cached = try? Self.objectListCache.entry(forKey: selectedSetCode) {
            objectList = cached.object
            return
        }

        let query: String
        if selectedSetCode.isEmpty {
            let codes = spoilingSets.map { "set:\($0.code)" }.joined(separator: " OR ")
            query = "(\(codes))"
        } else {
            query = "set:\(selectedSetCode)"
        }

        let client = ScryfallClient(logger: logger)
        let newObjectList = ScryfallObjectList<Card> { page in
            try await client.searchCards(
                query: query,
                unique: .prints,
                order: .spoiled,
                sortDirection: .desc,
                page: page,
            )
        }

        Self.objectListCache.setObject(newObjectList, forKey: selectedSetCode)
        objectList = newObjectList
        objectList.loadNextPage()
    }
}
