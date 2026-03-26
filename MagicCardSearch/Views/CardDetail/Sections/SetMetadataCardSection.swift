import SwiftUI
import ScryfallKit

struct SetMetadataCardSection: View {
    let setCode: String
    let setName: String
    let collectorNumber: String
    let rarity: Card.Rarity
    let lang: String
    let releasedAtAsDate: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                SetIconView(setCode: SetCode(setCode))

                VStack(alignment: .leading, spacing: 4) {
                    Text(setName)
                        .font(.body)
                        .fontWeight(.medium)

                    Text(
                        [
                            "\(setCode.uppercased()) #\(collectorNumber)",
                            rarity.rawValue.capitalized,
                            Language.name(forCode: lang),
                            releasedAtAsDate.map { $0.formatted(.dateTime.year().month().day()) },
                        ].compactMap(\.self).joined(separator: " • ")
                    )
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
