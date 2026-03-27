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
        NavigationStack {
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
        }
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
            LazyPagingCardDetailNavigatorView(
                list: SpoilersObjectList.shared,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates,
                searchState: nil,
            )
        }
    }

    @ViewBuilder
    private func spoilersGrid(results: ObjectList<Card>) -> some View {
        let grouped = groupByDate(results.data)

        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing, pinnedViews: .sectionHeaders) {
                ForEach(grouped, id: \.date) { section in
                    Section {
                        ForEach(Array(section.cards.enumerated()), id: \.element.id) { _, card in
                            let globalIndex = results.data.firstIndex { $0.id == card.id } ?? 0
                            CardView(
                                card: card,
                                quality: .normal,
                                isFlipped: $cardFlipStates.for(card.id),
                                cornerRadius: 10,
                                enableCopyActions: true,
                            )
                            .onTapGesture {
                                selectedCardIndex = globalIndex
                            }
                            .onAppear {
                                if globalIndex == results.data.count - 4 {
                                    spoilersList.loadNextPage()
                                }
                            }
                            .padding(.horizontal, spacing / 2)
                        }
                    } header: {
                        Text(section.date?.formatted() ?? "Unknown")
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(.background)
                    }
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

    private struct DateSection: Identifiable {
        let date: PlainDate?
        let cards: [Card]
        var id: PlainDate? { date }
    }

    private func groupByDate(_ cards: [Card]) -> [DateSection] {
        var unknownCards: [Card] = []
        var orderedDates: [PlainDate] = []
        var cardsByDate: [PlainDate: [Card]] = [:]

        for card in cards {
            if let rawDate = card.preview?.previewedAtAsDate {
                let date = PlainDate(date: rawDate)
                if cardsByDate[date] == nil {
                    orderedDates.append(date)
                }
                cardsByDate[date, default: []].append(card)
            } else {
                unknownCards.append(card)
            }
        }

        var sections: [DateSection] = []
        if !unknownCards.isEmpty {
            sections.append(DateSection(date: nil, cards: unknownCards))
        }
        sections += orderedDates.map { DateSection(date: $0, cards: cardsByDate[$0]!) }
        return sections
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
