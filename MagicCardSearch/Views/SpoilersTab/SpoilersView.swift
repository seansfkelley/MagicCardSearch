import SwiftUI
import ScryfallKit
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "SpoilersView")

struct SpoilersView: View {
    @State private var selectedCardIndex: Int?
    @State private var cardFlipStates: [UUID: Bool] = [:]

    private let spoilersList = SpoilersObjectList.shared

    private let columns = [
        GridItem(.flexible(), spacing: 0),
        GridItem(.flexible(), spacing: 0),
    ]

    private let spacing: CGFloat = 4

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            switch spoilersList.value {
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
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if isRunningTests() {
                logger.info("skipping spoilers load in test environment")
            } else {
                spoilersList.loadFirstPage()
            }
        }
        .sheet(
            item: Binding(
                get: { selectedCardIndex.map { IdentifiableIndex(index: $0) } },
                set: { selectedCardIndex = $0?.index }
            )
        ) { identifier in
            NavigationStack {
                LazyPagingCardDetailNavigatorView(
                    list: SpoilersObjectList.shared,
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
                            spoilersList.loadNextPage()
                        }
                    }
                    .padding(.horizontal, spacing / 2)
                }

                if (results.hasMore ?? false) || spoilersList.value.isLoadingNextPage {
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

// MARK: - Spoilers Data

@MainActor
@Observable
class SpoilersObjectList: ScryfallObjectList<Card> {
    private static let scryfall = ScryfallClient(logger: logger)

    static let shared = SpoilersObjectList { page async throws in
        return try await scryfall.searchCards(
            query: "date>=today",
            unique: .prints,
            order: .spoiled,
            sortDirection: .desc,
            page: page,
        )
    }

    func loadFirstPage() {
        if case .unloaded = value {
            loadNextPage()
        }
    }
}
