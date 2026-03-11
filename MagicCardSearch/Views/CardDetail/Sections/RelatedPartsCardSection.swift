import SwiftUI
import ScryfallKit

struct RelatedPartsCardSection: View {
    @ScaledMetric private var iconWidth = CardDetailConstants.defaultSectionIconWidth

    let otherParts: [Card.RelatedCard]
    let isLoadingRelatedCard: Bool
    let onPartTapped: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label("Related Parts", systemImage: "link")
                .labelReservedIconWidth(iconWidth)
                .font(.headline)
                .padding(.horizontal)
                .padding(.top, 17)
                .padding(.bottom, 10)

            ForEach(otherParts) { part in
                Button {
                    onPartTapped(part.id)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.body)
                                .foregroundStyle(.primary)

                            Text(part.typeLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        if isLoadingRelatedCard {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if part.id != otherParts.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
