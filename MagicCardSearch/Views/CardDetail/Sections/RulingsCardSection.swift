import SwiftUI
import ScryfallKit

struct RulingsCardSection: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CachingScryfallService.self) private var scryfallService
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let scryfallId: UUID

    @State private var rulings: StatefulLoadable<[Card.Ruling]>

    init(scryfallId: UUID) {
        self.scryfallId = scryfallId
        self.rulings = .init(fetcher: self.fetch)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Rulings", systemImage: "book.and.wrench")
                .labelReservedIconWidth(iconWidth)
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                switch rulings.value {
                case .unloaded, .loading:
                    HStack {
                        Text("Loading rulings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
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
                        Button("Try Again", action: {
                            Task {
                                await rulings.load(force: true)
                            }
                        })
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                    }
                }
            }
        }
        .tint(.primary)
        .padding()
        .onAppear {
            Task {
                await rulings.load()
            }
        }
        .onChange(of: scryfallId) {
            Task {
                await rulings.load(force: true)
            }
        }
    }

    private func fetch() async throws -> [Card.Ruling] {
        try await scryfallService.rulings(forScryfallId: scryfallId)
    }
}
