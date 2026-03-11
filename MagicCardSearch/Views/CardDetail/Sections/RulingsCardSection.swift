import SwiftUI
import ScryfallKit

struct RulingsCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let rulings: LoadableResult<[Card.Ruling], Error>
    let onRetry: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ScryfallCatalogs.self) private var scryfallCatalogs

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Rulings", systemImage: "book.and.wrench")
                .labelReservedIconWidth(iconWidth)
                .font(.headline)

            VStack(alignment: .leading, spacing: 16) {
                if case .loading = rulings {
                    HStack {
                        Text("Loading rulings...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                } else if case .errored(_, let error) = rulings {
                    ContentUnavailableView {
                        Label("Failed to Load Rulings", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error.localizedDescription)
                    } actions: {
                        Button("Try Again", action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                    }
                } else {
                    let builder = TextWithSymbolsBuilder(
                        fontSize: 17, // Seems to be the default? I dunno.
                        colorScheme: colorScheme,
                        scryfallCatalogs: scryfallCatalogs
                    )

                    ForEach(rulings.latestValue ?? []) { ruling in
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
                }
            }
        }
        .tint(.primary)
        .padding()
    }
}
