import SwiftUI
import ScryfallKit

struct RulingsCardSection<DividerContent: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(CachingScryfallService.self) private var scryfallService
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let scryfallId: UUID
    @ViewBuilder let divider: () -> DividerContent
    @State private var rulings: LoadableResult<[Card.Ruling], any Error> = .unloaded

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
        .onAppear {
            fetch()
        }
        .onChange(of: scryfallId) {
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
    init(scryfallId: UUID) {
        self.init(scryfallId: scryfallId) { EmptyView() }
    }
}
