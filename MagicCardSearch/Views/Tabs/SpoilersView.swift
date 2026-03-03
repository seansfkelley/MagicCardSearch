import SwiftUI
import ScryfallKit
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "SpoilersView")

struct SpoilersView: View {
    @Binding var searchState: SearchState
    @Binding var selectedTab: Tab

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
            LazyPagingCardDetailNavigator(
                list: SpoilersObjectList.shared,
                initialIndex: identifier.index,
                cardFlipStates: $cardFlipStates,
                searchState: $searchState,
            )
        }
    }

    @ViewBuilder
    private func spoilersGrid(results: ObjectList<Card>) -> some View {
        let grouped = groupByDate(results.data)

        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(grouped, id: \.date) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.label)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)

                        LazyVGrid(columns: columns, spacing: spacing) {
                            ForEach(Array(section.cards.enumerated()), id: \.element.id) { _, card in
                                let globalIndex = results.data.firstIndex { $0.id == card.id } ?? 0
                                CardView(
                                    card: card,
                                    quality: .normal,
                                    isFlipped: Binding(
                                        get: { cardFlipStates[card.id] ?? false },
                                        set: { cardFlipStates[card.id] = $0 }
                                    ),
                                    cornerRadius: 10,
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
                        }
                    }
                }

                if (results.hasMore ?? false) || spoilersList.value.isLoadingNextPage {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                }
            }
            .padding(.horizontal, spacing / 2)
            .padding(.vertical)
        }
    }

    private struct DateSection: Identifiable {
        let date: String
        let label: String
        let cards: [Card]
        var id: String { date }
    }

    private func groupByDate(_ cards: [Card]) -> [DateSection] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        var sections: [DateSection] = []
        var currentDateKey: String?
        var currentCards: [Card] = []

        for card in cards {
            let dateKey = card.releasedAt

            if dateKey != currentDateKey {
                if !currentCards.isEmpty, let key = currentDateKey {
                    let label = formatDateLabel(key, formatter: formatter)
                    sections.append(DateSection(date: key, label: label, cards: currentCards))
                }
                currentDateKey = dateKey
                currentCards = [card]
            } else {
                currentCards.append(card)
            }
        }

        if !currentCards.isEmpty, let key = currentDateKey {
            let label = formatDateLabel(key, formatter: formatter)
            sections.append(DateSection(date: key, label: label, cards: currentCards))
        }

        return sections
    }

    private func formatDateLabel(_ dateString: String, formatter: DateFormatter) -> String {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        if let date = isoFormatter.date(from: dateString) {
            return formatter.string(from: date)
        }
        return dateString
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
