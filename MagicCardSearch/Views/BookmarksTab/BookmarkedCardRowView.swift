import SwiftUI

struct BookmarkedCardRowView: View {
    let card: BookmarkedCard

    var body: some View {
        HStack(spacing: 10) {
            CardView(card: card, quality: .small, cornerRadius: 6)
                .frame(width: 60)

            VStack(alignment: .leading, spacing: 4) {
                Text(card.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)

                if let typeLine = card.typeLine {
                    Text(typeLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                HStack(spacing: 4) {
                    SetIconView(setCode: SetCode(card.setCode), size: 12)
                    Text(card.setCode.uppercased())
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("#\(card.collectorNumber)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("•")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(card.setName)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
