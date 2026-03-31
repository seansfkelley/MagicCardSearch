import SwiftUI
import ScryfallKit

@MainActor
protocol RulingsService {
    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling]
}

extension CachingScryfallService: RulingsService {}

struct RulingsCardSection<DividerContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let scryfallId: UUID
    let scryfallService: RulingsService
    @ViewBuilder let divider: () -> DividerContent
    @State private var rulings: LoadableResult<[Card.Ruling], any Error> = .unloaded

    init(scryfallId: UUID, scryfallService: RulingsService? = nil, @ViewBuilder divider: @escaping () -> DividerContent = { EmptyView() }) {
        self.scryfallId = scryfallId
        self.scryfallService = scryfallService ?? CachingScryfallService.shared
        self.divider = divider
    }

    var body: some View {
        Group {
            if case .loaded(let rulings, _) = rulings, rulings.isEmpty {
                EmptyView()
            } else {
                if case .unloaded = rulings {
                    // nop
                } else {
                    divider()
                }
                VStack(alignment: .leading, spacing: 12) {
                    Label("Rulings", systemImage: "book.and.wrench")
                        .labelReservedIconWidth(iconWidth)
                        .font(.headline)

                    VStack(alignment: .leading, spacing: 16) {
                        switch rulings {
                        case .unloaded, .loading:
                            ContentUnavailableView {
                                ProgressView()
                            } description: {
                                Text("Loading rulings...")
                                    .padding(.top)
                            }
                            .padding(.vertical)
                            .frame(maxWidth: .infinity, alignment: .center)
                        case .loaded(let rulings, _):
                            let builder = TextWithSymbolsBuilder(
                                fontSize: 17, // Seems to be the default? I dunno.
                                colorScheme: colorScheme,
                                scryfallCatalogs: scryfallCatalogs
                            )

                            ForEach(rulings) { ruling in
                                VStack(alignment: .leading, spacing: 6) {
                                    builder.buildText(ruling.comment)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)

                                    if let date = ruling.publishedAtAsDate {
                                        Text(date, format: .dateTime.year().month().day())
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        case .errored(_, let error):
                            ContentUnavailableView {
                                Label("Failed to Load Rulings", systemImage: "exclamationmark.triangle")
                            } description: {
                                Text(error.localizedDescription)
                            } actions: {
                                Button("Try Again", action: fetch)
                                    .buttonStyle(.borderedProminent)
                                    .tint(.blue)
                            }
                        }
                    }
                }
                .tint(.primary)
                .padding()
            }
        }
        .onChange(of: scryfallId, initial: true) {
            fetch()
        }
    }

    @MainActor
    private func fetch() {
        Task {
            await LoadableResult<[Card.Ruling], any Error>.load({ rulings = $0 }) {
                try await scryfallService.rulings(forScryfallId: scryfallId)
            }
        }
    }
}

extension RulingsCardSection where DividerContent == EmptyView {
    init(scryfallId: UUID, scryfallService: RulingsService?) {
        self.init(scryfallId: scryfallId, scryfallService: scryfallService) { EmptyView() }
    }
}

// MARK: - Previews
private struct MockRulingsService: RulingsService {
    enum Behavior {
        case loaded([Card.Ruling])
        case loadingForever
        case errored(any Error)
    }

    let behavior: Behavior

    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling] {
        switch behavior {
        case .loaded(let rulings):
            return rulings
        case .loadingForever:
            try await Task.sleep(for: .seconds(9999))
            return []
        case .errored(let error):
            throw error
        }
    }
}

private let sampleRulings: [Card.Ruling] = [
    Card.Ruling(
        source: .wotc,
        publishedAt: "2024-01-15",
        comment: "This ability uses the stack and can be responded to.",
        oracleId: "abc123"
    ),
    Card.Ruling(
        source: .wotc,
        publishedAt: "2023-06-02",
        comment: "If this permanent leaves the battlefield before the triggered ability resolves, you still draw a card.",
        oracleId: "abc123"
    ),
]

#Preview("Loaded with rulings") {
    ScrollView {
        RulingsCardSection(
            scryfallId: UUID(),
            scryfallService: MockRulingsService(behavior: .loaded(sampleRulings))
        )
    }
    .environment(ScryfallCatalogs())
}

#Preview("Loaded with no rulings") {
    ScrollView {
        RulingsCardSection(
            scryfallId: UUID(),
            scryfallService: MockRulingsService(behavior: .loaded([]))
        )
    }
    .environment(ScryfallCatalogs())
}

#Preview("Loading forever") {
    ScrollView {
        RulingsCardSection(
            scryfallId: UUID(),
            scryfallService: MockRulingsService(behavior: .loadingForever)
        )
    }
    .environment(ScryfallCatalogs())
}

#Preview("Errored") {
    ScrollView {
        RulingsCardSection(
            scryfallId: UUID(),
            scryfallService: MockRulingsService(behavior: .errored(URLError(.notConnectedToInternet)))
        )
    }
    .environment(ScryfallCatalogs())
}
